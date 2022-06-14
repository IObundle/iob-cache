#
# This file is included in BUILD_DIR/sim/Makefile
#


# add axi memory module
include ../../submodules/LIB/hardware/axiram/hardware.mk

#verilator top module
VTOP:=iob_cache_wrapper

test: iob-cache-clean-testlog test1
	diff -q test.log test.expected

test1: clean
	make run TEST_LOG=">> test.log"

.PHONY: test test1 debug


# add AXI4 wires
VHDR+=iob_cache_axi_wire.vh

iob_cache_axi_wire.vh:
	./software/python/axi_gen.py axi_wire iob_cache_ 
