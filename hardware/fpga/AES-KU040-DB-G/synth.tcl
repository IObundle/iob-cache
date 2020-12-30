#
# SYNTHESIS SCRIPT
#

#select top module and FPGA decive
set TOP iob_cache
## examples of TOP: iob_cache; iob_cache_axi; replacement_process;...
set PART xcku040-fbva676-1-c

set HW_INCLUDE [lindex $argv 0]
set VSRC [lindex $argv 1]

#verilog sources
foreach file [split $VSRC \ ] {
    if {$file != ""} {
        read_verilog -sv $file
    }
}

set_property part $PART [current_project]
#set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

read_xdc ./synth.xdc

synth_design -mode out_of_context -include_dirs $HW_INCLUDE -part $PART -top $TOP

#multiple tables showing the resources,but not for each module
#report_utilization

#table with all the modules, simplified
#report_utilization -hierarchical

opt_design


place_design

phys_opt_design

route_design

report_utilization -hierarchical

report_timing
