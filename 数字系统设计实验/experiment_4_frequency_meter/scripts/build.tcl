source [file join [file dirname [file normalize [info script]]] create_project.tcl]
set output_dir [file join $root output]
file mkdir $output_dir
set_param general.maxThreads 4
synth_design -top experiment4_top -part xc7a35tcsg324-1
write_checkpoint -force [file join $output_dir synthesized.dcp]
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $output_dir routed.dcp]
report_timing_summary -file [file join $output_dir timing.rpt]
report_drc -file [file join $output_dir drc.rpt]
report_io -file [file join $output_dir io.rpt]
report_exceptions -file [file join $output_dir exceptions.rpt]
report_timing -from [get_ports {ad_in[*]}] -max_paths 10 -file [file join $output_dir adc_setup.rpt]
report_utilization -file [file join $output_dir utilization.rpt]
foreach delay_type {max min} {
    set worst [get_timing_paths -delay_type $delay_type -max_paths 1]
    if {[llength $worst] == 0} { error "No $delay_type timing paths found" }
    if {[get_property SLACK $worst] < 0} { error "$delay_type timing failed" }
}
write_bitstream -force -bin_file [file join $output_dir experiment4_top.bit]
puts "BITSTREAM: [file join $output_dir experiment4_top.bit]"
