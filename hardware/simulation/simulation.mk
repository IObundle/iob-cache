MACRO_LIST+=VCD
include $(CACHE_DIR)/hardware/hardware.mk

#testbench source 
VSRC+=$(CACHE_HW_DIR)/simulation/testbench/iob_cache_tb.v

#axi memory
include $(AXI_DIR)/hardware/axiram/hardware.mk

waves:
	gtkwave uut.vcd

test: clean-testlog test1
	diff -q test.log test.expected

test1: clean
	make run VCD=0 TEST_LOG=">> test.log"

#clean test log only when tests begin

sim-clean: hw-clean
	@rm -rf *.vcd

.PHONY: waves test test1 sim-clean
