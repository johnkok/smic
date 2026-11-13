#ifndef BEAMFORMER_SPI_H
#define BEAMFORMER_SPI_H
#include <stdint.h>
typedef int (*bf_spi_transfer)(const uint8_t *tx,uint8_t *rx,unsigned n,void *ctx);
typedef struct {bf_spi_transfer transfer;void *ctx;float radius_m;float sound_speed;} bf_device;
int bf_write(bf_device *d,uint16_t addr,uint32_t value);
int bf_read(bf_device *d,uint16_t addr,uint32_t *value);
int bf_init(bf_device *d,float radius_m);
int bf_set_direction(bf_device *d,float azimuth_deg,float elevation_deg);
int bf_start(bf_device *d);
int bf_stop(bf_device *d);
#endif
