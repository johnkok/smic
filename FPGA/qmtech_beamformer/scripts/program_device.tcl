# Programs the XC7A100T volatile configuration SRAM over JTAG.
# Usage: ./scripts/run_vivado.sh -mode batch -source scripts/program_device.tcl
set bitstream [file normalize ./vivado_project/qmtech_beamformer.runs/impl_1/beamformer_top.bit]
if {![file exists $bitstream]} {
    error "Bitstream not found; run scripts/build_bitstream.tcl first"
}

open_hw_manager
connect_hw_server -allow_non_jtag
set targets [get_hw_targets -quiet]
if {[llength $targets] != 1} {
    error "Expected exactly one JTAG target, found [llength $targets]: $targets"
}
current_hw_target [lindex $targets 0]
open_hw_target

set matches {}
foreach device [get_hw_devices -quiet] {
    set part [get_property PART $device]
    puts "SMIC_JTAG_DEVICE=$device PART=$part IDCODE=[get_property IDCODE $device]"
    if {[string match -nocase "xc7a100t*" $part] ||
        [string match -nocase "*xc7a100t*" $device]} {
        lappend matches $device
    }
}
if {[llength $matches] != 1} {
    error "Expected exactly one XC7A100T in the JTAG chain, found [llength $matches]: $matches"
}

set device [lindex $matches 0]
current_hw_device $device
refresh_hw_device $device
set_property PROGRAM.FILE $bitstream $device
program_hw_devices $device
refresh_hw_device $device

set done_property REGISTER.IR.BIT5_DONE
if {[lsearch -exact [list_property $device] $done_property] >= 0} {
    puts "SMIC_PROGRAM_DONE=[get_property $done_property $device]"
}
puts "SMIC_PROGRAMMED_DEVICE=$device"
puts "SMIC_PROGRAMMED_BITSTREAM=$bitstream"
close_hw_target
disconnect_hw_server
exit
