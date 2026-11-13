---
name: qmtech-beamformer
description: "Use when working on the QMTech Artix-7 32-microphone beamformer in FPGA/qmtech_beamformer: reviewing or changing RTL, SPI host control, Fermat-spiral steering geometry, simulations, Vivado integration, audio output, or acoustic heat-map work."
---

# QMTech Beamformer Project Skill

## Scope
This skill applies to the beamformer prototype under `FPGA/qmtech_beamformer`.

## Target system
- FPGA: QMTECH Artix-7 XC7A100T DDR3 board.
- Inputs: 32 IM72D128 PDM microphones arranged as 16 edge-multiplexed data pairs.
- Final array geometry: a flat, 32-microphone Fermat spiral, replacing the prototype's circular-coordinate model.
- Each geometry-table X/Y location is the microphone package center. The table angle is both its polar position angle and physical PCB rotation.
- Steering calculations must use the rotated acoustic-port location, not the package center:
  `x_port = x_center + dx*cos(angle) - dy*sin(angle)` and
  `y_port = y_center + dx*sin(angle) + dy*cos(angle)`.
- Treat the port offset `(dx, dy)`, footprint origin, axis orientation, rotation direction, and units as board/datasheet inputs that must be verified before use.
- Outputs: SPI-controlled beamforming with selectable I2S/two-slot TDM audio. The requested direction display is a 360-degree horizontal acoustic heat map.
- A flat array can scan azimuth and elevation response, but cannot uniquely determine elevation sign without non-coplanar information; preserve this planar mirror-ambiguity limitation in code and documentation.

The checked-in RTL and host code are still a prototype based partly on circular-array assumptions. Treat the items above as the intended design, not as already implemented functionality. When changing geometry, update code, tests, and documentation together.

## Project layout
- `rtl/`: SystemVerilog RTL for the PDM frontend, beamformer core, SPI register block, and audio TX
- `host/`: C API for SPI register access and the current prototype steering calculations
- `sim/`: behavioral testbenches
- `constraints/`: pin and timing template
- `scripts/`: Vivado project creation script
- `docs/INTEGRATION.md`: hardware assumptions and integration limits

## Working rules
- Treat this as a prototype, not a production timing-closed design.
- Check the integration notes before changing clocking, SPI, or I/O assumptions.
- Prefer the smallest root-cause fix over broad refactors.
- Keep register maps and host-driver access aligned with the RTL.
- Verify changes with the project’s behavioral simulations whenever possible.

## Typical tasks
### RTL debugging
- Confirm module interfaces and port declarations are valid SystemVerilog.
- Trace SPI register writes and commits against the register map in `rtl/spi_regs.sv`.
- Check sample timing and `sample_tick` behavior before modifying the PDM or beam-core logic.

### Simulation validation
- Use `iverilog` to compile and run the behavioral testbenches.
- Reproduce the failing regression before changing code.
- Keep assertions and `$fatal` checks tied to actual project behavior.

### Vivado tools
- Use `/opt/AMD_II/2026.1/Vivado` as the selected Vivado installation.
- On hosts without ncurses5, run `scripts/setup_vivado_compat.sh`; it installs checksum-verified compatibility libraries inside the ignored project directory without root access.
- Invoke Vivado through `scripts/run_vivado.sh` so the project directory and AMD environment are set consistently.
- Do not silently fall back to `/opt/AMD/2026.1/Vivado`.

### Host API updates
- Keep the register addresses and bit ordering consistent with the FPGA implementation.
- Validate that `bf_set_direction()` and delay/gain writes match the Q-format used by `beam_core`.
- Maintain the documented SPI transaction format: opcode, big-endian address, big-endian 32-bit data.
- Do not derive final steering delays from nominal circular coordinates or uncorrected package centers. Use the supplied Fermat table plus the rotated acoustic-port offset.
- Keep geometry conversion and steering math host-side unless a task explicitly moves them into RTL; commit the resulting delay/gain bank atomically at an audio-frame boundary.

### Heat-map work
- Distinguish the single-beam audio path from direction scanning/energy estimation; a 360-degree heat map requires evaluating multiple steering directions over time or in parallel.
- Specify angular grid, update rate, integration window, band limits, normalization, and host transport before allocating FPGA resources.
- Do not claim 3D localization from the planar array. Report elevation candidates or ambiguity explicitly.

### Hardware integration review
- Review clocking assumptions and external audio reference requirements.
- Maintain safe wording around timing closure and board-specific pin compatibility.
- Update constraints and documentation when signal names or connection assumptions change.

## Suggested workflow
1. Read the relevant module and its surrounding documentation.
2. Reproduce the problem with the smallest available simulation or code path.
3. Fix the root cause and keep the change minimal.
4. Re-run the relevant simulation and record the result.
5. Update documentation only if the hardware or protocol assumptions changed.

## Important cautions
- Do not claim synthesis or board validation success without Vivado or hardware evidence.
- Do not assume the audio path is production-grade; the project notes explicitly call out required engineering before deployment.
- Keep naming and register conventions aligned between `rtl/`, `host/`, and `docs/INTEGRATION.md`.
- Do not describe the current circular host model, FIR/interpolation TODOs, or heat-map request as completed unless verified by code and tests.
