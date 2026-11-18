# EGO1 XC7A35T-1CSG324, 100 MHz oscillator.
set_property PACKAGE_PIN P17 [get_ports clk_in]
set_property PACKAGE_PIN P15 [get_ports sys_rst_n]
create_clock -name sys_clk -period 10.000 [get_ports clk_in]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# SW0 ... SW7; K[7] is SW7 (R1), K[0] is SW0 (P5).
set_property PACKAGE_PIN P5 [get_ports {sw[0]}]
set_property PACKAGE_PIN P4 [get_ports {sw[1]}]
set_property PACKAGE_PIN P3 [get_ports {sw[2]}]
set_property PACKAGE_PIN P2 [get_ports {sw[3]}]
set_property PACKAGE_PIN R2 [get_ports {sw[4]}]
set_property PACKAGE_PIN M4 [get_ports {sw[5]}]
set_property PACKAGE_PIN N4 [get_ports {sw[6]}]
set_property PACKAGE_PIN R1 [get_ports {sw[7]}]
set_property PACKAGE_PIN U3 [get_ports {dip[0]}]
set_property PACKAGE_PIN U2 [get_ports {dip[1]}]

# DN0 left four digits, DN1 right four digits; K1 ... K4 in each group.
set_property PACKAGE_PIN G2 [get_ports {seg_cs_pin[0]}]
set_property PACKAGE_PIN C2 [get_ports {seg_cs_pin[1]}]
set_property PACKAGE_PIN C1 [get_ports {seg_cs_pin[2]}]
set_property PACKAGE_PIN H1 [get_ports {seg_cs_pin[3]}]
set_property PACKAGE_PIN G1 [get_ports {seg_cs_pin[4]}]
set_property PACKAGE_PIN F1 [get_ports {seg_cs_pin[5]}]
set_property PACKAGE_PIN E1 [get_ports {seg_cs_pin[6]}]
set_property PACKAGE_PIN G6 [get_ports {seg_cs_pin[7]}]
set_property PACKAGE_PIN B4 [get_ports {seg_data_0_pin[0]}]
set_property PACKAGE_PIN A4 [get_ports {seg_data_0_pin[1]}]
set_property PACKAGE_PIN A3 [get_ports {seg_data_0_pin[2]}]
set_property PACKAGE_PIN B1 [get_ports {seg_data_0_pin[3]}]
set_property PACKAGE_PIN A1 [get_ports {seg_data_0_pin[4]}]
set_property PACKAGE_PIN B3 [get_ports {seg_data_0_pin[5]}]
set_property PACKAGE_PIN B2 [get_ports {seg_data_0_pin[6]}]
set_property PACKAGE_PIN D5 [get_ports {seg_data_0_pin[7]}]
set_property PACKAGE_PIN D4 [get_ports {seg_data_1_pin[0]}]
set_property PACKAGE_PIN E3 [get_ports {seg_data_1_pin[1]}]
set_property PACKAGE_PIN D3 [get_ports {seg_data_1_pin[2]}]
set_property PACKAGE_PIN F4 [get_ports {seg_data_1_pin[3]}]
set_property PACKAGE_PIN F3 [get_ports {seg_data_1_pin[4]}]
set_property PACKAGE_PIN E2 [get_ports {seg_data_1_pin[5]}]
set_property PACKAGE_PIN D2 [get_ports {seg_data_1_pin[6]}]
set_property PACKAGE_PIN H2 [get_ports {seg_data_1_pin[7]}]

# External MS9708 via J5/P1, using the existing EGo1.xdc wiring.
# ADDA schematic's DADB_13 ... DADB_6 are MS9708 D7 ... D0.
set_property PACKAGE_PIN B16 [get_ports clk_da]
set_property PACKAGE_PIN F13 [get_ports {sin_out[0]}]
set_property PACKAGE_PIN A18 [get_ports {sin_out[1]}]
set_property PACKAGE_PIN B18 [get_ports {sin_out[2]}]
set_property PACKAGE_PIN A14 [get_ports {sin_out[3]}]
set_property PACKAGE_PIN A13 [get_ports {sin_out[4]}]
set_property PACKAGE_PIN A16 [get_ports {sin_out[5]}]
set_property PACKAGE_PIN A15 [get_ports {sin_out[6]}]
set_property PACKAGE_PIN B17 [get_ports {sin_out[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports *]
set_property SLEW SLOW [get_ports {seg_cs_pin[*] seg_data_0_pin[*] seg_data_1_pin[*]}]
set_property DRIVE 8 [get_ports {clk_da sin_out[*]}]

# DAC forwarded clock: rising edge 50 ns after the data-update edge.
create_generated_clock -name dac_clk -source [get_ports clk_in] -edges {11 21 31} [get_ports clk_da]
# Conservative 4 ns setup / 2 ns hold budget, including PCB skew allowance.
set_output_delay -clock dac_clk -max 4.000 [get_ports {sin_out[*]}]
set_output_delay -clock dac_clk -min -2.000 [get_ports {sin_out[*]}]
# CE-controlled data launches occur at 0, 100, 200 ns; DAC captures at
# 50, 150, 250 ns. The default 100 MHz source analysis instead assumes
# a setup launch at 40 ns and a hold launch at 50 ns.
# Shift setup launch back four source cycles (40 -> 0), then shift the
# corresponding hold launch forward nine cycles (10 -> 100).
# Only the eight DAC data outputs are covered by these exceptions.
set_multicycle_path 5 -setup -start -from [get_clocks sys_clk] -to [get_ports {sin_out[*]}]
set_multicycle_path 9 -hold -start -from [get_clocks sys_clk] -to [get_ports {sin_out[*]}]
# Human-operated inputs have no synchronous timing relation to the oscillator.
set_false_path -from [get_ports {sw[*] dip[*] sys_rst_n}]
# Human-visible LEDs have no external capture clock.
set_false_path -to [get_ports {seg_cs_pin[*] seg_data_0_pin[*] seg_data_1_pin[*]}]
