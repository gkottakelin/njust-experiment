set script_dir [file dirname [file normalize [info script]]]
set root [file dirname $script_dir]
source [file join $script_dir tcl_store_path.tcl]
create_project experiment_5b_shift_100khz [file join $root vivado] -part xc7a35tcsg324-1 -force
add_files [glob [file join $root rtl *.v]]
add_files -fileset constrs_1 [file join $root constraints ego1.xdc]
add_files -fileset sim_1 [glob [file join $root sim *.sv]]
set_property top experiment5b_top [get_filesets sources_1]
set_property top tb_integration [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "PROJECT: [file join $root vivado experiment_5b_shift_100khz.xpr]"
