# root and lib paths
ROOT_DIR:=../..
LIB_DIR:=$(ROOT_DIR)/submodules/LIB

# core configuration
include $(ROOT_DIR)/config.mk

#MODULE HARDWARE
CACHE_DIR:=../..
include $(CACHE_DIR)/hardware/hardware.mk

# add verilog wrapper
VSRC+=iob_cache_wrapper.v

# add axi memory module
include $(LIB_DIR)/hardware/axiram/hardware.mk

# add AXI4 wires
VHDR+=iob_cache_axi_wire.vh
iob_cache_axi_wire.vh:
	set -e; $(AXI_GEN) axi_wire iob_cache_

#verilator top module
VTOP:=iob_cache_wrapper

# simulation segment
TOP_MODULE:=iob_cache
include $(LIB_DIR)/hardware/simulation/simulation.mk

# do not clean the below files
NOCLEAN:= -name 'Makefile' -o -name 'iob_cache_tb.v' -o -name 'iob_cache_tb.vh' -o -name 'rep_pol_tb.v' -o -name 'icarus.expected' -o -name 'iob_cache_tb.cpp' -o -name 'verilator.expected' -o -name 'iob_cache_wrapper.v'

test: iob-cache-clean-testlog test1
	diff -q test.log test.expected

test1: clean
	make run TEST_LOG=">> test.log"

debug:
	@echo $(REMOTE_ROOT_DIR)
	@echo $(ROOT_DIR)
	@echo $(CACHE_DIR)
	@echo $(VHDR)
	@echo $(VSRC)

.PHONY: test test1 debug
