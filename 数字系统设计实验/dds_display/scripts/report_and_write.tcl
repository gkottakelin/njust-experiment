report_timing_summary -file [file join $output_dir timing.rpt]
report_timing -from [get_clocks sys_clk] -to [get_ports {sin_out[*]}] -delay_type max -max_paths 8 -file [file join $output_dir dac_setup.rpt]
report_timing -from [get_clocks sys_clk] -to [get_ports {sin_out[*]}] -delay_type min -max_paths 8 -file [file join $output_dir dac_hold.rpt]
report_exceptions -file [file join $output_dir exceptions.rpt]
report_drc -file [file join $output_dir drc.rpt]
report_io -file [file join $output_dir io.rpt]
report_utilization -file [file join $output_dir utilization.rpt]
foreach delay_type {max min} {
    set worst [get_timing_paths -delay_type $delay_type -max_paths 1]
    if {[llength $worst] == 0} { error "No $delay_type timing paths found" }
    if {[get_property SLACK $worst] < 0} { error "$delay_type timing failed" }
}
write_bitstream -force -bin_file [file join $output_dir dds_display_top.bit]
puts "BITSTREAM: [file join $output_dir dds_display_top.bit]"
