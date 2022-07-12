create_clock -name "clk" -add -period 10.0 [get_ports {clk[0]}]
derive_clock_uncertainty
