---
name: qmtech-beamformer
description: "Use when working on the QMTech Artix-7 beamformer prototype in FPGA/qmtech_beamformer: reviewing RTL, debugging SystemVerilog, updating the SPI host API, validating behavioral simulations, or checking hardware integration assumptions in the Vivado project and constraints."
---

# QMTech Beamformer Project Skill

## Scope
This skill applies to the beamformer prototype under `FPGA/qmtech_beamformer`.

## Project layout
- `rtl/`: SystemVerilog RTL for the PDM frontend, beamformer core, SPI register block, and audio TX
- `host/`: C API for SPI register access and circular steering calculations
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

### Host API updates
- Keep the register addresses and bit ordering consistent with the FPGA implementation.
- Validate that `bf_set_direction()` and delay/gain writes match the Q-format used by `beam_core`.
- Maintain the documented SPI transaction format: opcode, big-endian address, big-endian 32-bit data.

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
