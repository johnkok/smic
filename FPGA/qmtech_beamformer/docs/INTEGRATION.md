# Integration / hardware review

## FPGA and clocks
The project defaults to the XC7A100T-1FGG676C specified by the supplied QMTECH V01 manual. It MUST match the marking on the fitted FPGA. The board's 50 MHz oscillator is not used. Feed an external low-jitter, 3.3 V 12.288 MHz reference to U2-18. U2-18/G20 is the P-side clock-capable input; U2-17/G21 is its N-side partner and cannot directly drive a BUFG as a single-ended input. This gives PDM_CLK=3.072 MHz, PCM=48 kHz and BCLK=3.072 MHz. Provide adequate timing constraints, especially for asynchronous SPI SCK.

## Physical connectivity
- 16 PDM data inputs, one shared PDM clock output distributed via a clock buffer with matched branches, 32 microphones in 16 edge-multiplexed pairs.
- Four SPI pins (SCK, CS_N, MOSI, MISO), three DAI pins (BCLK, FS, SD), reset and the 12.288 MHz reference are assigned to U2. D5 indicates enabled/running and D6 indicates register access; both LEDs are active-low.
- The IM72D128V01 supports operation from a 3.3 V supply. Power the microphones at 3.3 V so their PDM clock/data levels match U4 bank 35, which remains at the QMTECH board's default 3.3 V. Leave R14 and R15 fitted. Verify the microphone-board regulator, decoupling and SELECT strapping before connection, and verify edge sampling on an oscilloscope.
- A 32-mic circular array of radius 100 mm has 19.6 mm adjacent center-to-center spacing. Its approximate spatial-aliasing limit is 8.7 kHz. Configure actual radius in the host driver. Circular planar arrays cannot uniquely resolve elevation sign and may have front/back ambiguity depending on acoustic mounting.

### U2: SPI and DAI

U2 is not a 1.8 V connector on this PCB. The selected signals are in FPGA bank 15, whose VCCO is fixed at 3.3 V. If the host/adapter uses 1.8 V, use translators: SCK, CS_N, MOSI, `audio_clk_12m288` and reset translate toward the FPGA; MISO, BCLK, FS and SD translate away from it. A direct 1.8 V input is not guaranteed to meet LVCMOS33 VIH.

| U2 pin | FPGA pin | Signal |
|---:|---|---|
| 20 | H21 | SPI SCK, P-side MRCC |
| 6 | E26 | SPI CS_N |
| 7 | D25 | SPI MOSI |
| 8 | E25 | SPI MISO |
| 9 | G26 | DAI BCLK |
| 10 | H26 | DAI FS |
| 11 | E23 | DAI SD |
| 12 | F23 | Reset, active-low |
| 18 | G20 | External 12.288 MHz reference |

### U4: microphone board

U4 pins 3 and 4 are the VCCO_34_35 input points only when R14/R15 are removed; they are not microphone power outputs. In this 3.3 V configuration leave R14/R15 fitted and power the microphone board from a separately verified 3.3 V rail. Never connect U4 pins 63/64 (`VIN`) to the microphone board.

The SMIC J1 signal row is ordered `CLK, NC, DATA1 ... DATA16` on even pins 2, 4, 6 ... 36; odd pins 1 ... 35 are ground and pins 37 ... 40 are the external 3.3 V input. A direct adapter preserves channel order as follows. This is a logical connector map only: `Board/smic/docs/DESIGN_REVIEW.md` records a DATA/CLOCK pad-routing defect that must be fixed before the microphone PCB is manufactured.

| SMIC J1 | U4 | FPGA pin | RTL signal |
|---:|---:|---|---|
| 2 | 21 | F2 | PDM_CLK |
| 6 | 5 | B5 | PDM_DATA[0] |
| 8 | 6 | A5 | PDM_DATA[1] |
| 10 | 7 | B4 | PDM_DATA[2] |
| 12 | 8 | A4 | PDM_DATA[3] |
| 14 | 9 | A3 | PDM_DATA[4] |
| 16 | 10 | A2 | PDM_DATA[5] |
| 18 | 11 | D4 | PDM_DATA[6] |
| 20 | 12 | C4 | PDM_DATA[7] |
| 22 | 13 | C2 | PDM_DATA[8] |
| 24 | 14 | B2 | PDM_DATA[9] |
| 26 | 15 | E5 | PDM_DATA[10] |
| 28 | 16 | D5 | PDM_DATA[11] |
| 30 | 17 | C1 | PDM_DATA[12] |
| 32 | 18 | B1 | PDM_DATA[13] |
| 34 | 19 | E1 | PDM_DATA[14] |
| 36 | 20 | D1 | PDM_DATA[15] |

### LEDs

D5 (FPGA T23) flashes at 1 Hz while CTRL bit 0 is set. D6 (FPGA R23) illuminates for at least 100 ms after every complete valid SPI read or write transaction. These onboard circuits remain at their native 3.3 V and are not external interfaces.

## Audio output
Mode bit 1 at 0 selects I2S-like stereo framing, mode bit 1 at 1 selects TDM-like 2-slot framing. Both use 64 BCLK per audio frame. This initial RTL supports one mono beam in slot 0, slot 1 zero. It is not a generic 8/16-channel TDM transmitter. Validate FS/data edge conventions against the intended codec/host; current audio_tx requires protocol-specific simulation and may need one-bit alignment adjustments.

## SPI
Mode 0; CS deasserted between 56-bit transactions. 0x02 WRITE, 0x03 READ, 16-bit big-endian byte address, 32-bit big-endian data. Write commits at CS rising. Registers are byte-addressed and 32-bit aligned. Keep SCK below 2 MHz for the current asynchronous capture scheme. Implement timing/CDC signoff before deployment.

## Registers
0x0000 ID=0xBF320001; 0x0004 CTRL (bit0 enable, bit1 mute); 0x0008 status placeholder; 0x000C 48000 read-only; 0x0010 MODE (bit1 TDM); 0x0014/0x0018 steering angles reserved (host calculates delays); 0x001C OUTPUT_GAIN Q1.15; 0x0020 enable mask; 0x0024 COMMIT bit0; 0x0028 frame count; 0x002C errors placeholder. Delay shadow: 0x0100 + 4*i Q16.16 samples, integer portion limited to 254. Gain shadow: 0x0200 + 4*i Q1.15. Levels: 0x0300 + 4*i.

## Signal-processing limitations
The first version uses CIC3 decimation and linear fractional interpolation. CIC passband droop and stopband rejection are NOT sufficient for a production-quality audio path. Add an FIR compensation/anti-alias filter and replace interpolation with a verified 4-tap Lagrange implementation. Fixed-point scaling, saturation and long-term integrator behavior need rigorous simulation. `beam_core` now time-multiplexes one 8192x24 simple-dual-port history memory and uses a pipelined Q0.24 reciprocal table instead of combinational division. One frame takes 195 of the 256 clocks available between 48 kHz samples. There is no MVDR, AEC, automatic calibration, AGC or multiple-beam support in this version.

## Onboard DDR3

DDR3 is deliberately not instantiated in the current design. The complete 32-channel, 256-sample, 24-bit delay history is only 196,608 bits (24 KiB), and Vivado maps it to six RAMB36 blocks. Block RAM gives deterministic latency and avoids a memory-controller clock domain in the real-time beam path.

The onboard DDR3 is a sensible future option for raw-audio capture, delays longer than 255 samples, multiple simultaneous beams, or host-accessible diagnostic buffers. Add it as a separate buffered subsystem rather than replacing the current per-frame BRAM engine directly. That work requires a MIG configuration matching the exact fitted DDR3 device and PCB revision, the board's dedicated DDR pinout and electrical constraints, controller reference/reset clocks, calibration-status handling, clock-domain crossing, and FIFOs that absorb refresh/burst latency. None of the DDR3 pins are currently present in `board_template.xdc`, and a bitstream must not be generated from guessed DDR3 parameters.

## Readiness
This package is a **functional RTL prototype**, not a verified production deliverable. Vivado 2026.1 synthesis for XC7A100T-1FGG676 completes with the history mapped to six RAMB36 blocks. The synthesis report uses 6,661 LUTs (10.51%), 9,389 registers (7.40%), 12 DSP48E1s (5.00%), and six RAMB36 plus one RAMB18 (4.81% of block-RAM tiles). The extra RAMB18 holds the reciprocal table. On 2026-11-14, implementation completed with zero unrouted nets, zero bitstream DRC errors, 63.356 ns worst setup slack and 0.023 ns worst hold slack on the constrained clocks. The resulting bitstream was loaded over JTAG into an identified XC7A100T and DONE read back as 1. External I/O delays and full CDC constraints remain incomplete, and audio/SPI operation has not yet been validated on the board. Do not assume production-quality audio or complete interface timing signoff.
