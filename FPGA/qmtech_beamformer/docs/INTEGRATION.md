# Integration / hardware review

## FPGA and clocks
The project targets an XC7A100T. The package in the TCL script is an assumption and MUST match the board's marking. The board's 50 MHz oscillator is not used. Feed an external low-jitter 12.288 MHz reference to a clock-capable FPGA pin, with voltage levels compatible with the selected I/O bank. This gives PDM_CLK=3.072 MHz, PCM=48 kHz, BCLK=3.072 MHz. Provide adequate timing constraints, especially for asynchronous SPI SCK.

## Physical connectivity
- 16 PDM data inputs, one shared PDM clock output distributed via a clock buffer with matched branches, 32 microphones in 16 edge-multiplexed pairs.
- Four SPI pins (SCK, CS_N, MOSI, MISO), three audio pins (BCLK, FS, SD), reset, clock, debug.
- Microphone VDD and SELECT polarity must be checked against the actual IM72D128V01 datasheet and the edge sampling verified on an oscilloscope. DATA levels must match bank VCCO or be level shifted.
- A 32-mic circular array of radius 100 mm has 19.6 mm adjacent center-to-center spacing. Its approximate spatial-aliasing limit is 8.7 kHz. Configure actual radius in the host driver. Circular planar arrays cannot uniquely resolve elevation sign and may have front/back ambiguity depending on acoustic mounting.

## Audio output
Mode bit 1 at 0 selects I2S-like stereo framing, mode bit 1 at 1 selects TDM-like 2-slot framing. Both use 64 BCLK per audio frame. This initial RTL supports one mono beam in slot 0, slot 1 zero. It is not a generic 8/16-channel TDM transmitter. Validate FS/data edge conventions against the intended codec/host; current audio_tx requires protocol-specific simulation and may need one-bit alignment adjustments.

## SPI
Mode 0; CS deasserted between 56-bit transactions. 0x02 WRITE, 0x03 READ, 16-bit big-endian byte address, 32-bit big-endian data. Write commits at CS rising. Registers are byte-addressed and 32-bit aligned. Keep SCK below 2 MHz for the current asynchronous capture scheme. Implement timing/CDC signoff before deployment.

## Registers
0x0000 ID=0xBF320001; 0x0004 CTRL (bit0 enable, bit1 mute); 0x0008 status placeholder; 0x000C 48000 read-only; 0x0010 MODE (bit1 TDM); 0x0014/0x0018 steering angles reserved (host calculates delays); 0x001C OUTPUT_GAIN Q1.15; 0x0020 enable mask; 0x0024 COMMIT bit0; 0x0028 frame count; 0x002C errors placeholder. Delay shadow: 0x0100 + 4*i Q16.16 samples, integer portion limited to 254. Gain shadow: 0x0200 + 4*i Q1.15. Levels: 0x0300 + 4*i.

## Signal-processing limitations
The first version uses CIC3 decimation and linear fractional interpolation. CIC passband droop and stopband rejection are NOT sufficient for a production-quality audio path. Add an FIR compensation/anti-alias filter and replace interpolation with a verified 4-tap Lagrange implementation. Fixed-point scaling, saturation, division and long-term integrator behavior need rigorous simulation. Beam_core uses large inferred sample RAM arrays and combinational division; resource utilization/timing is unverified and may exceed practical XC7A100T limits. For production, replace division with reciprocal multiplication and use BRAM-based multi-cycle RAM accesses. There is no MVDR, AEC, automatic calibration, AGC or multiple-beam support in this version.

## Readiness
This package is a **functional RTL prototype**, not a verified synthesis/implementation deliverable. It has not been compiled in Vivado or tested on the QMTECH board. Do not assume timing closure, physical pin compatibility or production-quality audio.
