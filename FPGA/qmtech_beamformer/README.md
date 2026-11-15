# QMTECH Artix-7 32-PDM circular beamformer — RTL prototype

Contains synthesizable-intent SystemVerilog modules, SPI C host driver, beam
heatmap/calibration tools, Vivado project TCL, XDC template, and behavioral
testbenches. The root [`../../README.md`](../../README.md#operating-the-beamformer)
documents SPI mode/timing, the register map, steering equations, synthetic test
mode, heatmap use, and the microphone calibration procedure. See
`docs/INTEGRATION.md` for hardware, safety, verification, and functionality
limitations.

## Quick start
1. Verify that the fitted device is the XC7A100T FGG676 and that the PCB is the documented QMTECH V01 revision.
2. Provide a 3.3 V external 12.288 MHz audio clock on U2-18. Do not connect/fabricate the current SMIC microphone PCB until the DATA/CLOCK routing blocker in `../../Board/smic/docs/DESIGN_REVIEW.md` is resolved; the intended J1-to-U4 map is listed in `docs/INTEGRATION.md`.
3. Keep U2 at its fixed 3.3 V level. Use level translators for any 1.8 V SPI/DAI host; do not wire a 1.8 V host directly to U2.
4. On Ubuntu releases without ncurses5, run `./scripts/setup_vivado_compat.sh` once. It downloads two checksum-verified legacy libraries into the ignored `.vivado-compat/` directory without requiring root access.
5. Run `./scripts/run_vivado.sh -mode batch -source scripts/create_vivado_project.tcl` from this project directory. The wrapper selects `/opt/AMD_II/2026.1/Vivado` and also works when invoked from another directory.
6. Run `./scripts/run_vivado.sh -mode batch -source scripts/synthesize.tcl`. Reports are written to `vivado_project/synth_utilization.rpt` and `vivado_project/synth_timing_summary.rpt`.
7. Run `./scripts/run_vivado.sh -mode batch -source scripts/build_bitstream.tcl` and review the implementation timing and DRC reports before programming.
8. Run `./scripts/run_vivado.sh -mode batch -source scripts/program_device.tcl` to load the bitstream into volatile FPGA SRAM over JTAG. This does not program the configuration flash.
9. To create the persistent boot image, run `./scripts/run_vivado.sh -mode batch -source scripts/generate_cfgmem.tcl`.
10. Program and verify the onboard Micron N25Q064A with `./scripts/run_vivado.sh -mode batch -source scripts/program_cfgmem.tcl`. This erases the existing power-on image.
11. Run behavioral simulations and review warnings, inferred memories, utilization and timing before programming.
12. Connect the SPI host driver using a callback that asserts CS for each 7-byte transaction.

### Files
- `rtl/`: FPGA logic
- `host/`: C API with arbitrary XYZ geometry and calibration, plus the
  far-field CSV/SVG heatmap generator
- `sim/`: SPI, beam-core, and synthetic-source behavioral testbenches
- `scripts/`: Vivado project generation, synthesis and launch helpers
- `constraints/`: clock and board pin template

### Important
This is an engineering starting point. It is not a fully verified, timing-closed implementation. Pin assignments were transcribed from the supplied QMTECH V01 manual and schematic, but must still be checked against the physical board before power-up. The beam history is now a time-multiplexed 8192x24 block RAM datapath that completes in 195 clocks per 48 kHz frame. In particular, the decimation filter, SPI CDC and I2S/TDM phase alignment require further engineering before field use.
