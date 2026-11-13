# QMTECH XC7A100T core board V01, FGG676 package.
# Pin numbers are connector positions from the board manual/schematic in Doc/.
# Verify the fitted FPGA marking and PCB revision before programming hardware.

# U2: SPI, DAI, reset and external audio reference. Bank 15 is fixed at 3.3 V
# on this board. If the connected host is 1.8 V, place voltage translators
# between U2 and the host; do not connect 1.8 V signals directly or merely
# change these IOSTANDARD properties to LVCMOS18.
set_property -dict {PACKAGE_PIN D26 IOSTANDARD LVCMOS33} [get_ports spi_sck]          ;# U2-5
set_property -dict {PACKAGE_PIN E26 IOSTANDARD LVCMOS33} [get_ports spi_cs_n]         ;# U2-6
set_property -dict {PACKAGE_PIN D25 IOSTANDARD LVCMOS33} [get_ports spi_mosi]         ;# U2-7
set_property -dict {PACKAGE_PIN E25 IOSTANDARD LVCMOS33} [get_ports spi_miso]         ;# U2-8
set_property -dict {PACKAGE_PIN G26 IOSTANDARD LVCMOS33} [get_ports audio_bclk]       ;# U2-9
set_property -dict {PACKAGE_PIN H26 IOSTANDARD LVCMOS33} [get_ports audio_fs]         ;# U2-10
set_property -dict {PACKAGE_PIN E23 IOSTANDARD LVCMOS33} [get_ports audio_sd]         ;# U2-11
set_property -dict {PACKAGE_PIN F23 IOSTANDARD LVCMOS33 PULLUP true} [get_ports rst_n] ;# U2-12
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS33} [get_ports audio_clk_12m288] ;# U2-17, clock-capable

# U4: 16 PDM data pairs and the shared microphone clock, all in bank 35.
# IM72D128V01 microphones and the FPGA bank are operated at 3.3 V. Leave R14
# and R15 fitted so VCCO_34_35 remains at the board's default 3.3 V.
set_property -dict {PACKAGE_PIN B5 IOSTANDARD LVCMOS33} [get_ports {pdm_data[0]}]   ;# U4-5
set_property -dict {PACKAGE_PIN A5 IOSTANDARD LVCMOS33} [get_ports {pdm_data[1]}]   ;# U4-6
set_property -dict {PACKAGE_PIN B4 IOSTANDARD LVCMOS33} [get_ports {pdm_data[2]}]   ;# U4-7
set_property -dict {PACKAGE_PIN A4 IOSTANDARD LVCMOS33} [get_ports {pdm_data[3]}]   ;# U4-8
set_property -dict {PACKAGE_PIN A3 IOSTANDARD LVCMOS33} [get_ports {pdm_data[4]}]   ;# U4-9
set_property -dict {PACKAGE_PIN A2 IOSTANDARD LVCMOS33} [get_ports {pdm_data[5]}]   ;# U4-10
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports {pdm_data[6]}]   ;# U4-11
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports {pdm_data[7]}]   ;# U4-12
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports {pdm_data[8]}]   ;# U4-13
set_property -dict {PACKAGE_PIN B2 IOSTANDARD LVCMOS33} [get_ports {pdm_data[9]}]   ;# U4-14
set_property -dict {PACKAGE_PIN E5 IOSTANDARD LVCMOS33} [get_ports {pdm_data[10]}]  ;# U4-15
set_property -dict {PACKAGE_PIN D5 IOSTANDARD LVCMOS33} [get_ports {pdm_data[11]}]  ;# U4-16
set_property -dict {PACKAGE_PIN C1 IOSTANDARD LVCMOS33} [get_ports {pdm_data[12]}]  ;# U4-17
set_property -dict {PACKAGE_PIN B1 IOSTANDARD LVCMOS33} [get_ports {pdm_data[13]}]  ;# U4-18
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33} [get_ports {pdm_data[14]}]  ;# U4-19
set_property -dict {PACKAGE_PIN D1 IOSTANDARD LVCMOS33} [get_ports {pdm_data[15]}]  ;# U4-20
set_property -dict {PACKAGE_PIN F2 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports pdm_clk] ;# U4-21

# On-board LEDs are active-low and remain on their native 3.3 V bank.
set_property -dict {PACKAGE_PIN T23 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports led_run_n]  ;# D5
set_property -dict {PACKAGE_PIN R23 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports led_regs_n] ;# D6

create_clock -name audio_ref -period 81.380208 [get_ports audio_clk_12m288]
create_clock -name spi_sck -period 500.000 [get_ports spi_sck]
set_clock_groups -asynchronous -group [get_clocks audio_ref] -group [get_clocks spi_sck]

# Board/adapter input and output delays must be added once the microphone,
# level-translator and host timing specifications are fixed.
