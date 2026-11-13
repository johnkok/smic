# QMTECH Artix-7 32-PDM circular beamformer — RTL prototype

Contains synthesizable-intent SystemVerilog modules, SPI C host driver, Vivado project TCL, XDC template and two behavioral testbenches. See `docs/INTEGRATION.md` for hardware, safety, verification and functionality limitations.

## Quick start
1. Verify the XC7A100T package and available FPGA I/O banks on the exact QMTECH PCB.
2. Provide a compatible external 12.288 MHz audio clock; connect 16 PDM data pairs and buffered microphone clock.
3. Fill in all PACKAGE_PIN and IOSTANDARD assignments in `constraints/board_template.xdc`.
4. Run `vivado -mode batch -source scripts/create_vivado_project.tcl` from the repository root.
5. Run behavioral simulations and review warnings, inferred memories, utilization and timing before programming.
6. Connect SPI host driver using a callback that asserts CS for each 7-byte transaction.

### Files
- `rtl/`: FPGA logic
- `host/`: C API, circular steering delay computation
- `sim/`: behavioral testbenches
- `scripts/`: Vivado project generator
- `constraints/`: clock and board pin template

### Important
This is an engineering starting point. It is not a fully verified, timing-closed implementation. In particular, the decimation filter, beam core memory inference, SPI CDC and I2S/TDM phase alignment require further engineering before field use.
