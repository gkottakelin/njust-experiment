# Work around this installation's incomplete package search path in this process.
set store [file join $::env(XILINX_VIVADO) data XilinxTclStore]
foreach package_dir [concat [glob -nocomplain -types d [file join $store support *]] [glob -nocomplain -types d [file join $store tclapp * *]]] {
    if {[file exists [file join $package_dir pkgIndex.tcl]]} {
        lappend auto_path $package_dir
    }
}
