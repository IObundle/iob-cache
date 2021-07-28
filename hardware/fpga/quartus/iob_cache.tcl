#
# Synthesis and implementation script
#

set QUARTUS_VERSION "18.0.0 Standard Edition"
set FAMILY "Cyclone V"

set TOP [lindex $argv 0]
set DEVICE [lindex $argv 1]
set VSRC [lindex $argv 2]
set HW_INCLUDE [lindex $argv 3]
set HW_DEFINE [lindex $argv 4]

project_new $TOP -overwrite

set_global_assignment -name FAMILY $FAMILY
set_global_assignment -name DEVICE $DEVICE
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name TOP_LEVEL_ENTITY $TOP
set_global_assignment -name VERILOG_INPUT_VERSION SYSTEMVERILOG_2005

#set_global_assignment -name ORIGINAL_QUARTUS_VERSION 18.0.0
#set_global_assignment -name PROJECT_CREATION_TIME_DATE "15:59:11  JANUARY 21, 2019"

#set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 256

#file search paths
foreach path [split $HW_INCLUDE \ ] {
    if {$path != ""} {
        set_global_assignment -name SEARCH_PATH $path
    }
}

#verilog macros
foreach macro [split $HW_DEFINE \ ] {
    if {$macro != ""} {
        set_global_assignment -name VERILOG_MACRO $macro
    }
}

#verilog sources
foreach file [split $VSRC \ ] {
    if {$file != ""} {
        set_global_assignment -name VERILOG_FILE $file
    }
}


set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top


set_global_assignment -name PARTITION_NETLIST_TYPE POST_SYNTH -section_id $TOP":"$TOP"_0"

set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id $TOP":"$TOP"_0"

set_global_assignment -name PARTITION_COLOR 39423 -section_id $TOP":"$TOP"_0"

set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top

set_global_assignment -name LAST_QUARTUS_VERSION $QUARTUS_VERSION
set_global_assignment -name SDC_FILE ../$TOP.sdc
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "23 MM HEAT SINK WITH 200 LFPM AIRFLOW"
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"

project_close
