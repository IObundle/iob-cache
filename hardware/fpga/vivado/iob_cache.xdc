# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT

create_clock -name "clk" -add -period 10.0 [get_ports clk]
set_property CFGBVS VCCO [current_design]
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clk]
