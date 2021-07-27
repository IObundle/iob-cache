#
# library and hdl search paths
set_attribute lib_search_path [list /opt/ic_tools/pdk/faraday/umc130/LL/fsc0l_d/2009Q2v3.0/GENERIC_CORE/FrontEnd/synopsys]
set_attribute library [list fsc0l_d_generic_core_tt1p2v25c.lib]
set_attribute hdl_search_path $INCLUDE
#
# verilog source files, defines and includes
echo "\n\n"
echo "INCLUDE=" $INCLUDE
echo "\n\n"
echo "DEFINE=" $DEFINE
echo "\n\n"
echo "VSRC=" $VSRC
echo "\n\n"
#
# verilog read
read_hdl -v2001 -define $DEFINE $VSRC
#
# elaborate
elaborate $TOP_MODULE
#
# constrains
define_clock -name clk -period 5000 [find / -port clk]
#
# synthesis
synthesize -to_mapped
#
# aditional
insert_tiehilo_cells -verbose
delete_unloaded_undriven -all *
#
# reports
report timing > timing_report.txt
report power > power_report.txt
report gates > gates_report.txt
report area > area_report.txt
#
# outputs
set TOP_SYNTH $TOP_MODULE
append TOP_SYNTH "_synth"
write_hdl -mapped -v2001 > $TOP_SYNTH.v
write_sdc -strict > $TOP_SYNTH.sdc
write_db -to_file $TOP_SYNTH.sdc
#
#
exit
