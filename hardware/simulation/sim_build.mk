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

#tests
test:
	make run SIMULATOR=icarus
	sync && sleep 1 && test "$$(cat test.log)" = "Test passed!"
	make run SIMULATOR=verilator
	sync && sleep 1 && test "$$(cat test.log)" = "Test passed!"
