# SMIC PCB design review

## Acoustic holes

The IM72D128V01 datasheet specifies package PG-LLGA-5-3 and recommends a
0.8 mm PCB sound port. The embedded microphone footprint uses a 0.8 mm NPTH at
local `(0.68, 0)` from the package origin. The KiCad source and the exported
`smic-NPTH.drl` agree on all 32 drill positions. Exact KiCad PCB coordinates,
pair names, and J1 data pins are in `mic_acoustic_holes.csv`.

The package origins are the nominal Fermat-array placement points. Acoustic
centers are therefore displaced by 0.68 mm in each microphone's rotated local
X direction. Back-silkscreen port circles have been centered on the exact NPTH
coordinates; they previously contained small rounding/placement errors.

## J1 pin order

The signal row is now named in physical ascending order. Odd pins 1 through 35
are ground returns.

| J1 pin | Signal | J1 pin | Signal |
|---:|---|---:|---|
| 1 | GND | 2 | PDM_CLK input |
| 3 | GND | 4 | NC |
| 5 | GND | 6 | PDM_DATA1 |
| 7 | GND | 8 | PDM_DATA2 |
| 9 | GND | 10 | PDM_DATA3 |
| 11 | GND | 12 | PDM_DATA4 |
| 13 | GND | 14 | PDM_DATA5 |
| 15 | GND | 16 | PDM_DATA6 |
| 17 | GND | 18 | PDM_DATA7 |
| 19 | GND | 20 | PDM_DATA8 |
| 21 | GND | 22 | PDM_DATA9 |
| 23 | GND | 24 | PDM_DATA10 |
| 25 | GND | 26 | PDM_DATA11 |
| 27 | GND | 28 | PDM_DATA12 |
| 29 | GND | 30 | PDM_DATA13 |
| 31 | GND | 32 | PDM_DATA14 |
| 33 | GND | 34 | PDM_DATA15 |
| 35 | GND | 36 | PDM_DATA16 |
| 37-40 | 3.3 V input | | |

This order maps to FPGA U4 `PDM_DATA[0]` through `PDM_DATA[15]` without channel
permutation: J1-6 maps to U4-5, J1-8 to U4-6, continuing through J1-36 to
U4-20. J1-2 maps to U4-21 (`PDM_CLK`). The adapter/cable must also carry the
ground row and provide the microphone board with a separately verified 3.3 V
supply; U4 does not provide microphone power.

## 3.3 V population option

The source now selects the board's existing bypass option for 3.3 V operation:
U2 (`LP5907MFX-1.8`) is DNP and R18 is populated as 0 ohm. The internal supply
net is named `+3V3`. This is required for direct 3.3 V logic compatibility with
QMTECH U4 and also gives U1 (`74FCT3807S`) its intended supply range. Do not
populate U2 and R18 simultaneously.

## Manufacturing blocker

Do **not** fabricate the existing Gerber archive yet. The present copper routes
connect the U1 clock-fanout nets to IM72D128V01 physical pin 1 (`DATA`) and the
paired data nets to physical pin 3 (`CLOCK`). The schematic has the same
reversal. Correcting it requires rerouting every microphone connection—not
renaming nets or crossing the two final traces. An attempted straight endpoint
swap produces copper crossings, so it was not retained.

After that reroute, run ERC/DRC, inspect every microphone and J1 visually, and
regenerate all Gerber, drill, position, and BOM files from the same KiCad
revision. The committed manufacturing output predates the source changes and
must not be treated as released production data.
