set script_dir [file dirname [file normalize [info script]]]
set root [file dirname $script_dir]
source [file join $script_dir tcl_store_path.tcl]
set bitfile [file join $root output dds_display_top.bit]
if {![file exists $bitfile]} { error "Bitstream not found: $bitfile" }

open_hw_manager
connect_hw_server
set targets [get_hw_targets]
puts "JTAG_TARGETS: $targets"
if {[llength $targets] != 1} {
    error "Expected exactly one JTAG target; found [llength $targets]. No device was programmed."
}
current_hw_target [lindex $targets 0]
open_hw_target
set matching_devices {}
foreach device [get_hw_devices] {
    set part [get_property PART $device]
    puts "JTAG_DEVICE: $device PART=$part"
    if {[string match -nocase xc7a35t* $part]} { lappend matching_devices $device }
}
if {[llength $matching_devices] != 1} {
    error "Expected exactly one XC7A35T device; found [llength $matching_devices]. No device was programmed."
}
set device [lindex $matching_devices 0]
current_hw_device $device
set_property PROGRAM.FILE $bitfile $device
puts "PROGRAMMING: $device BITSTREAM=$bitfile"
program_hw_devices $device
refresh_hw_device -update_hw_probes false $device
report_property -file [file join $root output hardware_after_programming.rpt] $device
foreach property [list_property $device] {
    if {[regexp -nocase {done} $property]} {
        puts "DEVICE_STATUS: $property=[get_property $property $device]"
    }
}
puts "PROGRAM_BOARD_SUCCESS: $device"
close_hw_manager
