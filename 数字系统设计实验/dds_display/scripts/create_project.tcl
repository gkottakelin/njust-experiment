set script_dir [file dirname [file normalize [info script]]]
set root [file dirname $script_dir]
source [file join $script_dir tcl_store_path.tcl]
create_project dds_display [file join $root vivado] -part xc7a35tcsg324-1 -force
add_files [glob [file join $root rtl *.v]]
add_files -fileset constrs_1 [file join $root constraints ego1_dds.xdc]
add_files -fileset sim_1 [file join $root sim tb_dds_display.sv]
set_property top dds_display_top [get_filesets sources_1]
set_property top tb_dds_display [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Created [file join $root vivado dds_display.xpr]"
