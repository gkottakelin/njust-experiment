# Use only when RTL is unchanged and output/routed.dcp matches the RTL.
# Recheck an existing routed design after an external timing-constraint edit.
set script_dir [file dirname [file normalize [info script]]]
set root [file dirname $script_dir]
set output_dir [file join $root output]
source [file join $script_dir tcl_store_path.tcl]
set_param general.maxThreads 4
open_checkpoint [file join $output_dir routed.dcp]
read_xdc [file join $root constraints ego1_dds.xdc]
write_checkpoint -force [file join $output_dir routed.dcp]
source [file join $script_dir report_and_write.tcl]
