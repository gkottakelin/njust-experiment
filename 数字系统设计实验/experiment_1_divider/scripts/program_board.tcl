set script_dir [file dirname [file normalize [info script]]]
set root [file dirname $script_dir]
source [file join $script_dir tcl_store_path.tcl]
set bitfile [file join $root output clock_divider_top.bit]
if {![file exists $bitfile]} { error "Bitstream not found: $bitfile" }
open_hw_manager
connect_hw_server
set targets [get_hw_targets]
if {[llength $targets] != 1} { error "Expected one JTAG target; no device was programmed" }
current_hw_target [lindex $targets 0]
open_hw_target
set matching_devices {}
foreach device [get_hw_devices] {
    if {[string match -nocase xc7a35t* [get_property PART $device]]} {
        lappend matching_devices $device
    }
}
if {[llength $matching_devices] != 1} { error "Expected one XC7A35T; no device was programmed" }
set device [lindex $matching_devices 0]
current_hw_device $device
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device
refresh_hw_device -update_hw_probes false $device
report_property -file [file join $root output hardware_after_programming.rpt] $device
set done [get_property REGISTER.IR.BIT5_DONE $device]
puts "DEVICE_DONE: $done"
if {$done ne "1"} { error "FPGA DONE is not asserted" }
puts "PROGRAM_BOARD_SUCCESS: $device BITSTREAM=$bitfile"
close_hw_manager
