# SMIC schematic and PCB production review

## Verdict

**The microphone board is fully routed, but it is not ready for production.**
It is suitable only as a design-review prototype until the P0 release blockers
below are resolved and a new manufacturing package is generated.

This review was run on 2026-11-17 against the current KiCad sources with KiCad
10.0.8. It did not modify the schematic or PCB.

## Verified baseline

| Item | Current result |
|---|---|
| PCB | Two copper layers, 1.6 mm nominal thickness, 128.1626 mm diameter/extent |
| Components | 101 footprints: 32 microphones, 38 capacitors, 18 resistors, 10 test points, U1, U2, and J1 |
| Routing | 954 segments, 287 through vias, three copper zones |
| Track/via geometry | 0.254 mm minimum routed width; 0.246 mm reported minimum track clearance; all vias 0.8/0.4 mm |
| Connectivity | KiCad DRC reports zero unconnected pads |
| Acoustic holes | All 32 NPTH centres match `mic_acoustic_holes.csv` within 0.000002 mm; every drill is 0.8 mm |
| Microphone orientation | Only 0/90/180/270-degree package rotations are used |
| ERC | **Fail:** 19 errors and one warning |
| DRC | **Fail:** 32 errors and 15 warnings; zero unrouted items |
| Manufacturing files | Gerber, drill, and Gerber-job files exist, but the release package is incomplete and blocked |

The regenerated Gerber/drill output was compared with
`Board/smic/smic/Gerber/`. All layers match after creation metadata is ignored;
the F.Cu file contains the same `/CLK10` commands in a different net-section
order. This confirms that the files represent the current geometry, but it does
**not** make them safe to manufacture while ERC/DRC and hardware issues remain.

## P0 release blockers

### 1. ERC must be made clean and intentional

KiCad reports 19 ERC errors:

- 16 output-to-output errors are the paired microphone DATA outputs. Sharing is
  electrically intentional because complementary SELECT straps make one PDM
  output high-impedance on each half-cycle, but the symbol currently declares
  DATA as an ordinary output. Change the reviewed project-local microphone
  symbol to the appropriate tri-state electrical type, update all instances,
  and rerun ERC. Do not simply exclude 16 errors.
- GND and `VDD` are reported as power inputs with no power-output source. Add
  intentional power flags for the selected supply variant. Check `+3V3` as
  well: the DNP regulator output currently makes ERC appear to drive this net
  even though the 3.3 V build obtains it through R18.
- J1 pin 4 is intentionally unused but has no schematic no-connect marker. Add
  the marker and retain the PCB no-connect net.
- The project cannot resolve symbol library `smic`. The library exists at
  `Board/smic/smic.kicad_sym`, one directory above the KiCad project, but there
  is no checked-in `sym-lib-table`. Move/freeze the library inside the project
  or add a portable `${KIPRJMOD}` mapping.

The current schematic-to-PCB assignments otherwise pass source inspection:
microphone pin 1 is DATA, pin 3 is CLOCK, each DATA net has two complementary
SELECT straps, and all ten U1 outputs are now used.

### 2. Resolve the microphone footprint and all 32 hole-clearance errors

DRC reports the same error at every microphone: the 0.8 mm acoustic NPTH has
only 0.18 mm clearance to pad 5 copper, below the configured 0.25 mm minimum.
This is an intentional-looking part of the custom ground-pad geometry, but an
NPTH drill tolerance can expose or cut adjacent copper. Obtain the chosen
fabricator's written NPTH-to-copper capability and then either revise the pad or
encode a reviewed footprint-specific rule. Do not use stale coordinate-based
exclusions.

The project currently contains 29 old hole-clearance exclusions, yet all 32
errors are still reported because the item identifiers no longer match. Remove
these stale exclusions before release.

The PCB footprint is named `Infineon_PG-LLGA-5-2`, while IM72D128V01 is ordered
in PG-LLGA-5-3, and its embedded description points to an IM73A135 document.
KiCad also reports 15 local footprint/library mismatches. Create one
project-local `IM72D128V01_PG-LLGA-5-3` footprint and verify, against the local
Infineon datasheet:

- pin numbering and package orientation;
- solder-mask-defined copper pads and stencil apertures;
- the 0.8 mm sound port at the verified 0.68 mm package offset;
- pad-5-to-NPTH clearance and manufacturing tolerance;
- courtyard, fabrication outline, centroid, and 3D orientation;
- identical footprint revision on all 32 microphones.

After updating footprints, recheck every acoustic-hole centre against the CSV;
the current exact alignment must not be lost.

### 3. Implement the microphone bypass requirement

The Infineon datasheet states that a 1 uF bypass capacitor shall be placed close
to each microphone VDD pad for best SNR, and separately strongly recommends a
local 100 nF capacitor. The board has 32 nominal 100 nF capacitors but only two
1 uF capacitors total. The closest 100 nF footprint to each microphone is
2.866-3.657 mm from the microphone origin.

Add and place the required 1 uF local bypassing, or obtain a documented vendor
design exception supported by noise measurements. Keep each VDD/GND loop
short, with a direct ground return that does not share a long neck with clock
or DATA return current.

At a 3.072 MHz PDM clock the datasheet gives 1.12 mA maximum per microphone
under its stated 1.8 V test conditions, or 35.84 mA for 32 microphones before
U1 and margin. The 3.3 V production supply must be sized and measured rather
than extrapolated from that value.

### 4. Freeze an unambiguous 3.3 V assembly variant and purchasing BOM

For the intended direct 3.3 V build:

- U2 (`LP5907MFX-1.8`) is DNP;
- R18 is populated as 0 ohm;
- J1 pins 37-40 receive regulated 3.3 V;
- U2 and R18 must never be populated together.

The net name `+3V3` becomes 1.8 V if U2 is fitted, so the alternative variant
is easy to misunderstand and is not directly compatible with 3.3 V FPGA input
thresholds. Rename the rail or remove the unused regulator option before a
production release.

The generated BOM has no manufacturer or MPN values. Capacitors are listed as
`0.1` and `1` without units, tolerances, dielectric, or voltage rating; J1 is
only `DATA`; and U1 is only `74FCT3807S`. Select exact orderable parts and
confirm that the U1 ordering code is the TSSOP-20 package used by the PCB. A
74FCT3807S family device supports 3.3 V, but the family name is not a purchasing
part number.

## P1 electrical and layout review

### Ground reference and power distribution

F.Cu has a broad GND zone. B.Cu is split into an inner GND polygon and a large
outer `+3V3` polygon, while signals are routed on both layers. Many outer clock
and DATA paths therefore do not have a continuous nearby ground reference, and
signal/via routing further cuts the two-layer return paths. The PDM clock is
only 3.072 MHz, but the microphone permits edges as fast as 13 ns, so return
path continuity still matters.

Prefer a four-layer board with an uninterrupted ground plane. If the board must
remain two-layer, make B.Cu predominantly continuous GND, distribute 3.3 V with
wide traces or local pours, minimize B.Cu signal routing, and inspect every
clock/DATA return path across the complete route.

The 217 GND stitching vias are not a substitute for a continuous reference
plane. Remove unnecessary vias after the return-current review rather than
accepting the current 287-via count only because DRC passes connectivity.

### Clock fanout and decoupling

All ten U1 outputs drive the 32 microphones in groups of two or four. The four
nearest nominal 100 nF capacitors to U1 are still 4.778-6.520 mm from the body.
Place one capacitor directly at each U1 supply/ground pair with the shortest
possible loop.

There are no clock-output source-series tuning footprints at U1. The ten 1.5 mm
clock test points and their branches add stubs. Add compact optional series
footprints at the fanout outputs, reduce test-point stubs, and validate at the
furthest microphones with an active probe. At 3.072 MHz, acceptance includes
48-52% duty cycle and no more than 13 ns rise/fall time at the microphone.

KiCad has no clock length/skew constraints for these nets. Do not claim matched
clock routing from connectivity alone. Review each U1-to-microphone path and
then base any additional tuning on measured timing and overshoot; propagation
delay is less important here than clean edges and a continuous return path.

### Shared PDM DATA nets

R2-R17 are nominal 22 ohm common-path resistors. Infineon shows an optional
resistor of about 100 ohms for ringing/overshoot control. Because two
alternating outputs share each bus, validate resistor value and location using
the assembled board, cable, and FPGA input capacitance. Confirm that the
high-impedance interval prevents bus contention on every pair.

### Connector, protection, and mechanics

- J1 is an unkeyed 2x20 1.27 mm SMT header. Use a keyed connector or keyed
  adapter and add unmistakable pin-1 and 3.3 V markings.
- Add connector-side bulk capacitance and footprints for optional ferrite/zero
  ohm filtering. Add ESD and reverse/overcurrent protection if the cable or
  supply is user-accessible.
- The board has no dedicated mounting/tooling holes and no global fiducials.
  Confirm enclosure retention, add assembly fiducials, and keep hardware away
  from acoustic ports and their cavities.
- There is no board name, revision, voltage, or assembly-variant text on the
  board silkscreen/fabrication layers. Add traceable release markings.
- Preserve equivalent acoustic cavities, mesh, gasket compression, and keepout
  geometry for all 32 ports. Do not expose ports to vacuum, air blast,
  ultrasonic cleaning, or liquid cleaning; use no-clean assembly and temporary
  protective tape as required by the microphone datasheet.

## Connector pin order

Odd pins 1-35 are ground returns. The signal row is:

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
| 37-40 | Regulated 3.3 V input | | |

J1-6 maps to FPGA U4-5, J1-8 to U4-6, continuing through J1-36 to
U4-20. J1-2 maps to U4-21. U4 does not supply microphone power.

## Manufacturing package status

The checked-in `Board/smic/smic/Gerber/` directory contains the current copper,
mask, paste, silkscreen, outline, plated/non-plated drill, and Gerber job files.
It is still **blocked from fabrication**. The release is missing at least:

- a clean ERC report and reviewed/clean DRC report;
- released BOM with approved MPNs and explicit DNP/fit variant;
- pick-and-place/centroid files;
- schematic PDF, assembly drawings, and fabrication drawing/notes;
- stackup, copper weight, finish, solder-mask, impedance/non-impedance, panel,
  tolerance, and acoustic-port handling requirements;
- IPC-356/netlist comparison if required by the assembler;
- board revision/tag tying every output to one source commit.

Do not send the current Gerbers to a manufacturer merely because they were
recently generated.

## Production release gates

1. Freeze exact MPNs, 3.3 V population variant, project-local symbol library,
   and the corrected PG-LLGA-5-3 footprint.
2. Add the required local microphone and U1 bypassing; review ground-return and
   power-distribution topology.
3. Resolve all ERC errors by modeling real electrical intent, not broad
   exclusions.
4. Resolve the 32 NPTH clearance errors with the fabricator and remove stale
   DRC exclusions; update all 32 microphone footprints identically.
5. Add keying/markings, fiducials, mounting strategy, protection, and acoustic
   assembly requirements.
6. Refill zones and obtain zero unintended ERC/DRC findings and zero unrouted
   items in KiCad 10.
7. Re-verify all 32 NPTH centres against `mic_acoustic_holes.csv`, connector
   mapping, SELECT polarity, and the U1 clock destination for every microphone.
8. Generate BOM, position files, schematic/assembly/fabrication PDFs, Gerbers,
   drills, job file, and optional IPC-356 from one tagged source revision.
9. Inspect mask/paste/sound ports and all manufacturing layers in an independent
   viewer, then perform netlist and drill-count comparisons.
10. Build a small pilot lot. Inspect paste/reflow and ports; test supply current,
    all clocks and 16 PDM pairs, channel order, noise, sensitivity, calibration,
    and beam pattern before authorizing production quantity.
