---
name: rtl-verification
description: "Use when validating FPGA RTL behavior, reproducing simulation failures, debugging module interfaces, or checking that the QMTech beamformer and related SystemVerilog modules still satisfy their behavioral tests."
---

# RTL Verification Skill

## Use this skill when
- compiling or debugging Verilog/SystemVerilog modules
- reproducing a failing testbench or runtime assertion
- confirming that register writes, sample timing, and output values match the intended behavior
- checking whether a fix is supported by simulation evidence before claiming completion

## Verification workflow
1. Reproduce the issue with the smallest relevant simulation.
2. Read the exact failing module and testbench together.
3. Identify the root cause before changing RTL or host-side logic.
4. Apply the minimal fix and keep the change narrowly scoped.
5. Re-run the relevant testbench and confirm the result with fresh output.

## Project-specific checks
- Compile the beamformer and SPI benches with `iverilog` before and after changes.
- For `spi_regs.sv`, validate the register map and write/commit behavior.
- For `beam_core.sv`, validate the delay-and-sum output stays within expected bounds for constant input.
- Treat warnings and timing assumptions as part of the verification story, not as proof of correctness.

## Guardrails
- Do not claim the design is validated on hardware without hardware or Vivado evidence.
- Do not broaden the change beyond the actual root cause.
- Keep the simulation output and the resulting fix matched to the same module being tested.
