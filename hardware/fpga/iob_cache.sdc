####################################################################
#
#
#   Description: Constraints File
#
#   Copyright (C) 2018 IObundle, Lda  All rights reserved
#
#####################################################################

#common
create_clock -name "clk" -add -period 10.0 [get_ports clk]

#quartus
derive_clock_uncertainty

#vivado
set_property CFGBVS VCCO [current_design]
