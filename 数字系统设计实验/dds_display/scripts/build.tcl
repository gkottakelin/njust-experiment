source [file join [file dirname [file normalize [info script]]] create_project.tcl]
# Use one Vivado process so building does not depend on Windows Script Host
# or launch_runs child-process initialization on this installation.
set output_dir [file join $root output]
file mkdir $output_dir
set_param general.maxThreads 4
synth_design -top dds_display_top -part xc7a35tcsg324-1
write_checkpoint -force [file join $output_dir synthesized.dcp]
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $output_dir routed.dcp]
source [file join $script_dir report_and_write.tcl]
