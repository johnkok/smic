#include "beamformer_spi.h"
#include <math.h>
#include <string.h>
#define PI 3.14159265358979323846
static int exchange(bf_device *d,uint8_t op,uint16_t a,uint32_t *v){
 uint8_t tx[7]={op,(uint8_t)(a>>8),(uint8_t)a,0,0,0,0},rx[7]={0};
 if(op==2){tx[3]=(uint8_t)(*v>>24);tx[4]=(uint8_t)(*v>>16);tx[5]=(uint8_t)(*v>>8);tx[6]=(uint8_t)*v;}
 if(!d||!d->transfer)return -1;
 int rc=d->transfer(tx,rx,7,d->ctx);if(rc)return rc;
 if(op==3)*v=((uint32_t)rx[3]<<24)|((uint32_t)rx[4]<<16)|((uint32_t)rx[5]<<8)|rx[6];
 return 0;
}
int bf_write(bf_device*d,uint16_t a,uint32_t v){return exchange(d,2,a,&v);}
int bf_read(bf_device*d,uint16_t a,uint32_t*v){return exchange(d,3,a,v);}
int bf_init(bf_device*d,float radius_m){
 if(!d||radius_m<=0)return -1;
 d->radius_m=radius_m;d->sound_speed=343.0f;
 if(bf_write(d,0x0004,0))return -1;
 if(bf_write(d,0x0010,0))return -1;
 if(bf_write(d,0x001c,32768))return -1;
 if(bf_write(d,0x0020,0xffffffffu))return -1;
 for(int i=0;i<32;i++)if(bf_write(d,0x0200+4*i,32768))return -1;
 return bf_set_direction(d,0,0);
}
int bf_set_direction(bf_device*d,float azimuth_deg,float elevation_deg){
 if(!d)return -1;
 double az=azimuth_deg*PI/180.0,el=elevation_deg*PI/180.0;
 double delays[32],min=1e30;
 for(int i=0;i<32;i++){
  double a=2.0*PI*i/32.0;
  // microphone positions: x=R cos(a), y=R sin(a), z=0
  double proj=d->radius_m*cos(el)*cos(a-az);
  delays[i]=-proj/d->sound_speed*48000.0;
  if(delays[i]<min)min=delays[i];
 }
 for(int i=0;i<32;i++){
  double v=(delays[i]-min)*65536.0;
  if(v<0||v>254.0*65536.0)return -2;
  if(bf_write(d,0x0100+4*i,(uint32_t)llround(v)))return -3;
 }
 return bf_write(d,0x0024,1);
}
int bf_start(bf_device*d){return bf_write(d,0x0004,1);}
int bf_stop(bf_device*d){return bf_write(d,0x0004,0);}
