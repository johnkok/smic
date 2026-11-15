#include "beamformer_spi.h"
#include <math.h>
#include <string.h>

#define PI 3.14159265358979323846

static int exchange(bf_device *d, uint8_t op, uint16_t a, uint32_t *v) {
 uint8_t tx[7] = {op, (uint8_t)(a >> 8), (uint8_t)a, 0, 0, 0, 0};
 uint8_t rx[7] = {0};
 int rc;
 if (!d || !d->transfer || !v) return -1;
 if (op == 2) {
  tx[3] = (uint8_t)(*v >> 24); tx[4] = (uint8_t)(*v >> 16);
  tx[5] = (uint8_t)(*v >> 8); tx[6] = (uint8_t)*v;
 }
 rc = d->transfer(tx, rx, 7, d->ctx);
 if (rc) return rc;
 if (op == 3)
  *v = ((uint32_t)rx[3] << 24) | ((uint32_t)rx[4] << 16) |
       ((uint32_t)rx[5] << 8) | rx[6];
 return 0;
}

int bf_write(bf_device *d, uint16_t a, uint32_t v) {
 return exchange(d, 2, a, &v);
}
int bf_read(bf_device *d, uint16_t a, uint32_t *v) {
 return exchange(d, 3, a, v);
}

int bf_init(bf_device *d, float radius_m) {
 int i;
 if (!d || radius_m <= 0.0f) return -1;
 d->radius_m = radius_m;
 d->sound_speed = 343.0f;
 for (i = 0; i < BF_CHANNELS; ++i) {
  double a = 2.0 * PI * i / BF_CHANNELS;
  d->position[i].x_m = (float)(radius_m * cos(a));
  d->position[i].y_m = (float)(radius_m * sin(a));
  d->position[i].z_m = 0.0f;
  d->calibration[i].gain_linear = 1.0f;
  d->calibration[i].delay_samples = 0.0f;
  d->calibration[i].invert = 0;
 }
 if (bf_write(d, BF_REG_CTRL, 0) || bf_write(d, BF_REG_MODE, 0) ||
     bf_write(d, BF_REG_OUTPUT_GAIN, 32768) ||
     bf_write(d, BF_REG_ENABLE_MASK, 0xffffffffu) ||
     bf_write(d, BF_REG_TEST_CONTROL, 0)) return -1;
 return bf_set_direction(d, 0.0f, 0.0f);
}

int bf_set_geometry(bf_device *d,
                    const bf_mic_position position[BF_CHANNELS]) {
 if (!d || !position) return -1;
 memcpy(d->position, position, sizeof(d->position));
 return 0;
}

int bf_set_calibration(
    bf_device *d, const bf_mic_calibration calibration[BF_CHANNELS]) {
 int i;
 if (!d || !calibration) return -1;
 for (i = 0; i < BF_CHANNELS; ++i) {
  if (!isfinite(calibration[i].gain_linear) ||
      calibration[i].gain_linear < 0.0f ||
      calibration[i].gain_linear > (65535.0f / 32768.0f) ||
      !isfinite(calibration[i].delay_samples)) return -2;
 }
 memcpy(d->calibration, calibration, sizeof(d->calibration));
 return 0;
}

int bf_set_direction(bf_device *d, float azimuth_deg, float elevation_deg) {
 double az, el, ux, uy, uz, raw[BF_CHANNELS], minimum = 1e30;
 uint32_t polarity = 0;
 int i;
 if (!d || d->sound_speed <= 0.0f) return -1;
 az = azimuth_deg * PI / 180.0;
 el = elevation_deg * PI / 180.0;
 ux = cos(el) * cos(az); uy = cos(el) * sin(az); uz = sin(el);
 for (i = 0; i < BF_CHANNELS; ++i) {
  double projection = d->position[i].x_m * ux +
                      d->position[i].y_m * uy +
                      d->position[i].z_m * uz;
  raw[i] = -projection / d->sound_speed * BF_SAMPLE_RATE_HZ +
           d->calibration[i].delay_samples;
  if (raw[i] < minimum) minimum = raw[i];
 }
 for (i = 0; i < BF_CHANNELS; ++i) {
  double delay_q16 = (raw[i] - minimum) * 65536.0;
  double gain_q15 = d->calibration[i].gain_linear * 32768.0;
  if (delay_q16 < 0.0 || delay_q16 > 254.0 * 65536.0) return -2;
  if (bf_write(d, (uint16_t)(BF_REG_DELAY_BASE + 4 * i),
               (uint32_t)llround(delay_q16)) ||
      bf_write(d, (uint16_t)(BF_REG_GAIN_BASE + 4 * i),
               (uint32_t)llround(gain_q15))) return -3;
  if (d->calibration[i].invert) polarity |= 1u << i;
 }
 if (bf_write(d, BF_REG_POLARITY_MASK, polarity)) return -3;
 return bf_write(d, BF_REG_COMMIT, 1);
}

int bf_set_test_mode(bf_device *d, enum bf_test_pattern pattern,
                     unsigned channel, int all_channels, int32_t amplitude) {
 uint32_t control;
 if (!d || pattern < BF_TEST_SQUARE_1KHZ || pattern > BF_TEST_ALTERNATING ||
     channel >= BF_CHANNELS || amplitude < -8388608 || amplitude > 8388607)
  return -1;
 control = 1u | (all_channels ? 2u : 0u) | (channel << 2) |
           ((uint32_t)pattern << 8);
 if (bf_write(d, BF_REG_TEST_AMPLITUDE,
              (uint32_t)amplitude & 0x00ffffffu)) return -2;
 return bf_write(d, BF_REG_TEST_CONTROL, control);
}
int bf_disable_test_mode(bf_device *d) {
 return bf_write(d, BF_REG_TEST_CONTROL, 0);
}
int bf_start(bf_device *d) { return bf_write(d, BF_REG_CTRL, 1); }
int bf_stop(bf_device *d) { return bf_write(d, BF_REG_CTRL, 0); }
