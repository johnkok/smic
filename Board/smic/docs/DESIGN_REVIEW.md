# SMIC schematic and PCB design review

## Review scope and present status

This review covers the current KiCad 10 schematic and PCB sources. It is a
source-level review, not a manufacturing release. A compatible KiCad 10 CLI is
not installed in the review environment, so ERC, DRC, zone refill, and
manufacturing-output comparison still have to be run in KiCad 10.

The current PCB contains 100 footprints: 32 microphones, 38 capacitors, 18
resistors, nine test points, U1/U2, and J1. All 32 microphone acoustic NPTHs and
their 32 back-silkscreen circles coincide with the coordinates in
`mic_acoustic_holes.csv`; the microphone bodies use only 0/90/180/270-degree
orientations.

The board is intentionally **unrouted**: it contains zero track segments and
zero routing vias. Its three saved copper-zone fills predate the new routing and
placement state and are not release evidence. Refill them only after routing.
The checked-in Gerber and drill files are historical and must not be fabricated.

## Schematic and net-assignment findings

Source inspection confirms the intended IM72D128V01 pin assignment is now used
in the schematic-derived PCB nets:

- pin 1 (`DATA`) connects to one of `DATA1` through `DATA16`;
- pin 3 (`CLOCK`) connects to one of the nine U1 fanout branches;
- each DATA net has two microphones with complementary pin-4 SELECT straps;
- R2 through R17 connect the 16 DATA nets to J1 even pins 6 through 36;
- J1-2 feeds the clock input through R1, and J1-4 is unused;
- U1 uses nine of its ten outputs; its Q1 output is unused;
- U2 is marked DNP and R18 is the populated 0-ohm 3.3 V bypass.

This corrects the older DATA/CLOCK-reversal finding. It does not prove the
schematic is error-free: run ERC after completing the recommendations below and
resolve every warning or explicitly documented intentional no-connect.

## Acoustic geometry and footprint

The IM72D128V01 PG-LLGA-5-3 recommendation uses a 0.8 mm PCB sound port. The
embedded footprint places that NPTH at local `(0.68, 0)` from the package
origin. Package origins are offset as required so the actual NPTH—not the
reference origin—lands on the Fermat coordinate. Use
`mic_acoustic_holes.csv` for beamforming and calibration.

Before release, create or freeze a project-local, reviewed microphone footprint.
Verify pin numbering, solder-mask-defined pads, paste apertures, the 0.8 mm
sound port, courtyard, pick-and-place origin, and the package/3D-model naming
against the exact ordered microphone variant. The datasheet prohibits vacuum or
air-blast exposure of the port and recommends no-clean assembly and temporary
port protection; add those requirements to the assembly drawing.

## Connector pin order

Odd pins 1 through 35 are ground returns. The signal row is:

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

J1-6 maps to FPGA U4-5, J1-8 to U4-6, continuing through J1-36 to
U4-20. J1-2 maps to U4-21. U4 does not supply microphone power; the adapter
must carry ground and the separately regulated 3.3 V rail.

## Placement and circuit recommendations

| Priority | Recommended modification | Reason and acceptance criterion |
|---|---|---|
| P0 | Route from the corrected net assignments, then refill zones and run ERC/DRC. | The board currently has no tracks or vias. Release only with zero unintended unrouted items and reviewed ERC/DRC reports. |
| P0 | Freeze and verify the microphone footprint and assembly process. | A pin, mask, paste, or sound-port error affects all 32 channels. Inspect the generated paste/mask/drill output against the Infineon drawing. |
| P1 | Move each 100 nF microphone capacitor immediately beside its VDD/GND pads with a minimal loop. | Current nearest-capacitor distances are 2.69–4.78 mm center-to-center; the microphone datasheet calls for close local bypassing. Confirm whether the datasheet's additional 1 µF bypass note applies per microphone or per local rail group. |
| P1 | Move U1 nearer the connector/array center and place one 100 nF capacitor at each of its four VDD pins. | U1 is about 27 mm from the array center and its four nearest capacitors are 4.78–6.52 mm away. A central fanout shortens and balances the nine radial clock branches. |
| P1 | Add optional 22–47 ohm source-series footprints at the nine U1 clock outputs, placed directly at U1. | The outputs drive two or four microphones over long radial branches. Populate values only after oscilloscope testing for overshoot and edge rate. At 3.072 MHz, verify the microphone-clock duty cycle remains within 48–52% and rise/fall time within 13 ns. Avoid large test-point stubs. |
| P1 | Treat R1 as a tuning option and put the actual clock source damping at the FPGA/adapter driver. | A receiver-side series resistor cannot provide ideal source termination for the cable. Validate the complete FPGA-to-array interconnect at 3.072 MHz. |
| P1 | Prefer a four-layer stackup with a continuous ground plane; otherwise reserve one two-layer face as continuously as possible for ground. | The present B.Cu split between `+3V3` and GND can disrupt return paths. Do not route PDM clocks/data across plane splits; distribute 3.3 V with a wide ring/pour and frequent local ground stitching. |
| P1 | Add connector-side bulk decoupling and optional input filtering/protection. | Keep the existing 1 µF parts, and provide footprints for roughly 4.7–10 µF bulk capacitance, a ferrite/0-ohm option, and—if the cable is externally accessible—low-capacitance ESD and reverse/overcurrent protection. Select parts from measured current and transient data. |
| P1 | Replace or key J1, or provide a keyed adapter with an unmistakable pin-1 mark and voltage label. | The current unshrouded 2x20 header can be offset or reversed. A wrong connection can place power on signals. |
| P2 | Add dedicated `VDD`, `+3V3`, GND, clock-input, and representative DATA test pads with nearby ground probe pads. | The existing nine 1.5 mm test points monitor only clock branches and can add stubs. Use compact probe pads and document expected waveforms. |
| P2 | Add three global fiducials and enclosure-compatible mounting/tooling features. | The current design has only the 32 acoustic NPTHs and no separate mounting/tooling holes or fiducials. Keep mechanical hardware and copper outside acoustic keepouts. |
| P2 | Add board name/revision, 3.3 V warning, J1 pin-1, DNP/bypass note, and microphone orientation marks to silkscreen/assembly layers. | These markings reduce assembly and bring-up errors and make photographs traceable to a revision. |

## Routing and layout guidance

- Lock the verified microphone and acoustic-hole positions before routing.
- Route U1 clock branches first. Keep them short, avoid stubs, keep a continuous
  ground reference, and do not force exact length matching unless measurement
  shows it is needed.
- Route each shared DATA net between its two complementary microphones and J1
  without branch loops. Keep R2–R17 consistently near J1 as configurable
  isolation/tuning elements. The microphone datasheet suggests about 100 ohms
  as an optional ringing-control value; do not freeze the present 22-ohm choice
  without measuring the assembled two-source bus and cable.
- Keep clocks separated from DATA traces and microphone VDD pads. Do not route
  a fast edge around an acoustic port or beneath a microphone unless the
  footprint/vendor guidance explicitly permits it.
- Use wide 3.3 V distribution, short capacitor returns, and ground stitching
  around the connector, U1, and array perimeter. Verify that zone islands are
  removed after every refill.
- Define copper, mask, paste, component, and enclosure keepouts around every
  sound port. The enclosure must not create unequal cavities or partially cover
  a port.

## 3.3 V population option

For direct 3.3 V operation, U2 (`LP5907MFX-1.8`) remains DNP and R18 is
populated as 0 ohm. Never populate both paths. Verify the BOM and assembly
drawing express these mutually exclusive variants, and measure the rail at the
furthest microphones during simultaneous operation.

## Manufacturing release gates

1. Complete the schematic review, add approved manufacturer part numbers, and
   run KiCad 10 ERC.
2. Freeze the microphone footprint, array CSV, connector mapping, and mechanical
   keepouts under a board revision.
3. Implement and review the clock, DATA, power, and ground routing; refill all
   zones and run KiCad 10 DRC.
4. Verify every microphone pin-1 DATA, pin-3 CLOCK, and complementary SELECT
   assignment against the schematic and datasheet.
5. Review decoupling placement, clock waveforms, return paths, connector keying,
   test access, fiducials, and mounting strategy.
6. Generate schematic PDF, BOM, position files, Gerbers, drill files, and the
   Gerber job file from the same tagged revision.
7. Compare all 32 NPTHs with `mic_acoustic_holes.csv` and inspect paste/mask
   apertures in an independent Gerber viewer.
8. Fabricate a small pilot batch, inspect it, and test power, clock, all 16 PDM
   pairs, channel order, noise, sensitivity, and beam pattern before production.
