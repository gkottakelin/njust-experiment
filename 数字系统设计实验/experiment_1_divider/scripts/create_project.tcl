set script_dir [file dirname [file normalize [info script]]]
set root [file dirname $script_dir]
source [file join $script_dir tcl_store_path.tcl]
create_project experiment_1_divider [file join $root vivado] -part xc7a35tcsg324-1 -force
add_files [file join $root rtl clock_divider_top.v]
add_files -fileset constrs_1 [file join $root constraints ego1_divider.xdc]
add_files -fileset sim_1 [file join $root sim tb_clock_divider.sv]
set_property top clock_divider_top [get_filesets sources_1]
set_property top tb_clock_divider [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "PROJECT: [file join $root vivado experiment_1_divider.xpr]"
