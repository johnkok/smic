# Generates an 8 MiB SPIx4 MCS image for the QMTECH V01 N25Q064A.
# Usage: ./scripts/run_vivado.sh -mode batch -source scripts/generate_cfgmem.tcl
set bitstream [file normalize ./vivado_project/qmtech_beamformer.runs/impl_1/beamformer_top.bit]
set output_dir [file normalize ./vivado_project/cfgmem]
set output_mcs [file join $output_dir beamformer_top_n25q64.mcs]

if {![file exists $bitstream]} {
    error "Bitstream not found; run scripts/build_bitstream.tcl first"
}
file mkdir $output_dir

write_cfgmem -force -format mcs -size 8 -interface SPIx4 \
    -loadbit "up 0x00000000 $bitstream" $output_mcs

set output_prm [file rootname $output_mcs].prm
if {![file exists $output_mcs] || ![file exists $output_prm]} {
    error "Vivado did not generate both MCS and PRM files"
}
puts "SMIC_CFGMEM_MCS=$output_mcs"
puts "SMIC_CFGMEM_PRM=$output_prm"
puts "SMIC_CFGMEM_PART=n25q64-3.3v-spi-x1_x2_x4"
exit
