#
# SYNTHESIS SCRIPT
#

#select top module and FPGA decive
set TOP iob_cache
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

read_xdc ./synth.xdc

synth_design -include_dirs $HW_INCLUDE -part $PART -top $TOP

report_utilization

