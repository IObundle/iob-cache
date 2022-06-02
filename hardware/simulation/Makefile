
CACHE_DIR:=../..
include $(CACHE_DIR)/config.mk

ROOT_DIR:=../..
include $(ROOT_DIR)/submodules/LIB/hardware/simulation/simulation.mk

NOCLEAN:= -name 'Makefile' -o -name 'iob_cache_tb.v' -o \
	-name 'iob_cache_tb.vh' -o -name 'rep_pol_tb.v' -o -name 'icarus.expected'\
	-name 'iob_cache_tb.cpp' -o -name 'verilator.expected' -o -name 'iob_cache_wrapper.v'


ifeq ($(VCD),1)
MACRO_LIST+=VCD
endif

include $(ROOT_DIR)/hardware/hardware.mk

#axi memory
include $(AXI_DIR)/hardware/axiram/hardware.mk

waves:
	gtkwave uut.vcd

test: iob-cache-clean-testlog test1
	diff -q test.log test.expected

test1: clean
	make run TEST_LOG=">> test.log"

#clean test log only when tests begin

sim-clean: iob-cache-hw-clean
	@rm -rf *.vcd

# AXI4 wires
VHDR+=iob_cache_axi_wire.vh
iob_cache_axi_wire.vh:
	set -e; $(AXI_GEN) axi_wire iob_cache_


.PHONY: waves test test1 sim-clean
