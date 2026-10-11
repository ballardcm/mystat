#pragma once
#include <stdint.h>
#include <stdbool.h>
typedef struct MSCSensor MSCSensor;
MSCSensor *msc_open(void);
void msc_close(MSCSensor *sensor);
bool msc_read(MSCSensor *sensor, const char *key, double *value);
bool msc_key_at(MSCSensor *sensor, uint32_t index, char key[5]);
typedef struct MSPower MSPower;
typedef struct { double cpu, gpu, ane, dram; } MSPowerSample;
MSPower *msp_open(int os_major);
MSPowerSample msp_sample(MSPower *power);
void msp_close(MSPower *power);

double ms_energy_watts(int64_t energy, const char *unit, double elapsed);
