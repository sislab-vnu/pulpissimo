if {$argc != 2} {
    error "Usage: program_cfgmem.tcl MCS_FILE CFGMEM_PART"
}

set mcs_file [file normalize [lindex $argv 0]]
set cfgmem_part_name [lindex $argv 1]

if {![file exists $mcs_file]} {
    error "Configuration-memory image does not exist: $mcs_file"
}

open_hw_manager
set hw_server_url TCP:localhost:3121
if {[info exists ::env(HW_SERVER_URL)]} {
    set hw_server_url $::env(HW_SERVER_URL)
}
connect_hw_server -url $hw_server_url

set targets [get_hw_targets]
if {[info exists ::env(HW_TARGET)] && $::env(HW_TARGET) ne ""} {
    set targets [get_hw_targets -quiet $::env(HW_TARGET)]
}
if {[llength $targets] != 1} {
    error "Expected one hardware target on $hw_server_url, found [llength $targets]; set HW_TARGET to select one"
}
open_hw_target [lindex $targets 0]

set devices [get_hw_devices -quiet -filter {PART =~ "xc7a100t*"}]
if {[llength $devices] != 1} {
    error "Expected one xc7a100t device on $hw_server_url, found [llength $devices]"
}
set device [lindex $devices 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device

set cfgmem_parts [get_cfgmem_parts -quiet $cfgmem_part_name]
if {[llength $cfgmem_parts] == 0} {
    error "Unknown configuration-memory part: $cfgmem_part_name"
}

create_hw_cfgmem -hw_device $device [lindex $cfgmem_parts 0]
set cfgmem [get_property PROGRAM.HW_CFGMEM $device]
set_property PROGRAM.ADDRESS_RANGE use_file $cfgmem
set_property PROGRAM.FILES [list $mcs_file] $cfgmem
set_property PROGRAM.PRM_FILE {} $cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION pull-none $cfgmem
set_property PROGRAM.BLANK_CHECK 0 $cfgmem
set_property PROGRAM.ERASE 1 $cfgmem
set_property PROGRAM.CFG_PROGRAM 1 $cfgmem
set_property PROGRAM.VERIFY 1 $cfgmem
set_property PROGRAM.CHECKSUM 0 $cfgmem

startgroup
if {![string equal [get_property PROGRAM.HW_CFGMEM_TYPE $device] \
                   [get_property MEM_TYPE [get_property CFGMEM_PART $cfgmem]]]} {
    create_hw_bitstream -hw_device $device \
        [get_property PROGRAM.HW_CFGMEM_BITFILE $device]
    program_hw_devices $device
    refresh_hw_device $device
}
program_hw_cfgmem -hw_cfgmem $cfgmem
endgroup

puts "Programmed and verified $mcs_file using $cfgmem_part_name"
