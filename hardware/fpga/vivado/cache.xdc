create_clock -name clk -period 10.000 [get_ports clk]
set_property CFGBVS VCCO [current_design]
