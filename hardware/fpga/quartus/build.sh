#!/usr/bin/bash
export ALTERAPATH=/home/iobundle/Intel/Altera_full/18.0
export LM_LICENSE_FILE=1801@localhost:$ALTERAPATH/../1-MVXX5H_License.dat
nios=/home/iobundle/Intel/Altera_full/18.0/nios2eds/nios2_command_shell.sh

$nios quartus_sh -t ../$1.tcl "$1" "$2" "$3" "$4" "$5"
$nios quartus_map --read_settings_files=on --write_settings_files=off $1 -c $1
$nios quartus_fit --read_settings_files=off --write_settings_files=off $1 -c $1
$nios quartus_cdb --read_settings_files=off --write_settings_files=off $1 -c $1 --merge=on
$nios quartus_cdb $1 -c $1 --incremental_compilation_export=iob_timer_0.qxp --incremental_compilation_export_partition_name=Top --incremental_compilation_export_post_synth=on --incremental_compilation_export_post_fit=off --incremental_compilation_export_routing=on --incremental_compilation_export_flatten=on

