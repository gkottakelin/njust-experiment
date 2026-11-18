# Pin assignments follow the Experiment 1 slide.
set_property PACKAGE_PIN P17 [get_ports clk_in]
set_property PACKAGE_PIN R11 [get_ports rst]
set_property PACKAGE_PIN J2 [get_ports clk_10mhz]
set_property PACKAGE_PIN J3 [get_ports clk_1khz]
set_property IOSTANDARD LVCMOS33 [get_ports *]
set_property SLEW SLOW [get_ports {clk_10mhz clk_1khz}]
set_property DRIVE 8 [get_ports {clk_10mhz clk_1khz}]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

create_clock -name sys_clk -period 10.000 [get_ports clk_in]
create_generated_clock -name divided_10mhz -source [get_ports clk_in] -divide_by 10 [get_ports clk_10mhz]
create_generated_clock -name divided_1khz -source [get_ports clk_in] -divide_by 100000 [get_ports clk_1khz]
# Manual asynchronous reset has no input timing relation to the oscillator.
set_false_path -from [get_ports rst]
