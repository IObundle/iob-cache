#
# This file is included in BUILD_DIR/sim/Makefile
#

#verilator top module
VTOP:=iob_cache_tb

ifeq ($(SIMULATOR),verilator)
VHDR+=iob_cache_tb.cpp
VTOP:=iob_cache_sim_wrapper
endif

iob_cache_tb.cpp: ./src/iob_cache_tb.cpp
	cp $< $@
