#!/bin/bash
set -e
nios=$QUARTUSPATH/nios2eds/nios2_command_shell.sh

$nios quartus_sh -t ../cache.tcl "$1" "$2" "$3" "$4" "$5"
$nios quartus_map --read_settings_files=on --write_settings_files=off $1 -c $1
$nios quartus_fit --read_settings_files=off --write_settings_files=off $1 -c $1
$nios quartus_cdb --read_settings_files=off --write_settings_files=off $1 -c $1 --merge=on
$nios quartus_cdb iob_cache -c iob_cache --incremental_compilation_export=iob_cache_0.qxp --incremental_compilation_export_partition_name=Top --incremental_compilation_export_post_synth=on --incremental_compilation_export_post_fit=off --incremental_compilation_export_routing=on --incremental_compilation_export_flatten=on

