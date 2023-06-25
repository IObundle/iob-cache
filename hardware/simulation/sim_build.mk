#
# This file is included in BUILD_DIR/sim/Makefile
#

ifeq ($(SIMULATOR),verilator)
VHDR+=iob_cache_tb.cpp
endif

iob_cache_tb.cpp: ./src/iob_cache_tb.cpp
	cp $< $@

#verilator top module
#VTOP:=iob_cache_sim_wrapper

#tests
TEST_LIST+=test1
test1:
	make run SIMULATOR=icarus

#TEST_LIST+=test2
test2:
	make clean SIMULATOR=icarus && make run SIMULATOR=verilator
