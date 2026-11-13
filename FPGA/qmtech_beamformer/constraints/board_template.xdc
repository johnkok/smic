# WARNING: NO PACKAGE_PIN assignments are supplied: QMTECH board variant and bank voltages MUST be checked.
# The external 12.288 MHz reference is REQUIRED for accurate 48k audio in this build.
create_clock -period 81.380208 [get_ports audio_clk_12m288]
# Set correct bank VCCO and IOSTANDARD based on verified board schematic.
# Example only (NOT enabled): set_property PACKAGE_PIN <VERIFIED_PIN> [get_ports {pdm_data[0]}]
# Example only (NOT enabled): set_property IOSTANDARD LVCMOS18 [get_ports {pdm_data[*]}]
# WARNING: SPI SCK is a separate asynchronous clock domain; CDC constraints and verification needed.
