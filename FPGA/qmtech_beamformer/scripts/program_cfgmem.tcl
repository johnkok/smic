# Programs and verifies the QMTECH V01 onboard N25Q064A configuration flash.
# Usage: ./scripts/run_vivado.sh -mode batch -source scripts/program_cfgmem.tcl
set cfgmem_name n25q64-3.3v-spi-x1_x2_x4
set mcs_file [file normalize ./vivado_project/cfgmem/beamformer_top_n25q64.mcs]
set prm_file [file normalize ./vivado_project/cfgmem/beamformer_top_n25q64.prm]

foreach required [list $mcs_file $prm_file] {
    if {![file exists $required]} {
        error "Configuration-memory file not found: $required"
    }
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

set cfgmem_parts [get_cfgmem_parts -quiet $cfgmem_name]
if {[llength $cfgmem_parts] < 1} {
    error "Vivado configuration-memory part not found: $cfgmem_name"
}
create_hw_cfgmem -hw_device $device [lindex $cfgmem_parts 0]
set cfgmem [get_property PROGRAM.HW_CFGMEM $device]
if {$cfgmem eq ""} {
    error "Vivado did not attach a configuration-memory device"
}

set_property PROGRAM.ADDRESS_RANGE {use_file} $cfgmem
set_property PROGRAM.FILES [list $mcs_file] $cfgmem
set_property PROGRAM.PRM_FILE $prm_file $cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $cfgmem
set_property PROGRAM.BLANK_CHECK 0 $cfgmem
set_property PROGRAM.ERASE 1 $cfgmem
set_property PROGRAM.CFG_PROGRAM 1 $cfgmem
set_property PROGRAM.VERIFY 1 $cfgmem
set_property PROGRAM.CHECKSUM 0 $cfgmem

# Load Vivado's temporary flash-programming bridge into the FPGA, then erase,
# program, and read-verify the complete file range.
create_hw_bitstream -hw_device $device [get_property PROGRAM.HW_CFGMEM_BITFILE $device]
program_hw_devices $device
refresh_hw_device $device
program_hw_cfgmem -hw_cfgmem $cfgmem

puts "SMIC_CFGMEM_PROGRAMMED=$cfgmem_name"
puts "SMIC_CFGMEM_FILE=$mcs_file"
puts "SMIC_CFGMEM_VERIFY=COMPLETE"

# Reboot the FPGA from flash when supported so DONE verifies the nonvolatile
# image immediately, without requiring a manual power cycle.
if {[llength [info commands boot_hw_device]] > 0} {
    boot_hw_device $device
    after 3000
    refresh_hw_device $device
    set done_property REGISTER.IR.BIT5_DONE
    if {[lsearch -exact [list_property $device] $done_property] >= 0} {
        puts "SMIC_FLASH_BOOT_DONE=[get_property $done_property $device]"
    }
} else {
    puts "SMIC_FLASH_BOOT_DONE=NOT_CHECKED_COMMAND_UNAVAILABLE"
}

close_hw_target
disconnect_hw_server
exit
