set_attribute lib_search_path {/opt/ic_tools/pdk/faraday/umc130/HS/fsc0h_d/2009Q1v3.0/GENERIC_CORE/FrontEnd/synopsys ../asic_memories}
set_attribute hdl_search_path {../../verilog_src/ ../../ipb-xctrl/verilog_src/}
set_attribute library {fsc0h_d_generic_core_tt1p2v25c.lib SJHD130_2048X32X1CM4_TC.lib SEHD130_64X32X1CM4_TC.lib}

read_netlist xtop_synth.v
read_tcf ../sim/xtop.tcf 
report power > power_report.txt
exit
