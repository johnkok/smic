#ifndef BEAMFORMER_SPI_H
#define BEAMFORMER_SPI_H

#include <stdint.h>

#define BF_CHANNELS 32
#define BF_SAMPLE_RATE_HZ 48000.0f
#define BF_REG_CTRL 0x0004u
#define BF_REG_MODE 0x0010u
#define BF_REG_OUTPUT_GAIN 0x001cu
#define BF_REG_ENABLE_MASK 0x0020u
#define BF_REG_COMMIT 0x0024u
#define BF_REG_TEST_CONTROL 0x0030u
#define BF_REG_TEST_AMPLITUDE 0x0034u
#define BF_REG_POLARITY_MASK 0x0038u
#define BF_REG_DELAY_BASE 0x0100u
#define BF_REG_GAIN_BASE 0x0200u

typedef int (*bf_spi_transfer)(const uint8_t *tx, uint8_t *rx,
                              unsigned n, void *ctx);
typedef struct { float x_m, y_m, z_m; } bf_mic_position;
typedef struct {
 float gain_linear;
 float delay_samples;
 uint8_t invert;
} bf_mic_calibration;
typedef struct {
 bf_spi_transfer transfer;
 void *ctx;
 float radius_m;
 float sound_speed;
 bf_mic_position position[BF_CHANNELS];
 bf_mic_calibration calibration[BF_CHANNELS];
} bf_device;

enum bf_test_pattern {
 BF_TEST_SQUARE_1KHZ = 0,
 BF_TEST_IMPULSE_1KHZ = 1,
 BF_TEST_DC = 2,
 BF_TEST_ALTERNATING = 3
};

int bf_write(bf_device *d, uint16_t addr, uint32_t value);
int bf_read(bf_device *d, uint16_t addr, uint32_t *value);
int bf_init(bf_device *d, float radius_m);
int bf_set_geometry(bf_device *d, const bf_mic_position position[BF_CHANNELS]);
int bf_set_calibration(bf_device *d,
                       const bf_mic_calibration calibration[BF_CHANNELS]);
int bf_set_direction(bf_device *d, float azimuth_deg, float elevation_deg);
int bf_set_test_mode(bf_device *d, enum bf_test_pattern pattern,
                     unsigned channel, int all_channels, int32_t amplitude);
int bf_disable_test_mode(bf_device *d);
int bf_start(bf_device *d);
int bf_stop(bf_device *d);

#endif
