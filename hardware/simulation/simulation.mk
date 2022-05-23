MACRO_LIST+=VCD
include $(CACHE_DIR)/hardware/hardware.mk

#axi memory
include $(AXI_DIR)/hardware/axiram/hardware.mk

waves:
	gtkwave uut.vcd

test: iob-cache-clean-testlog test1
	diff -q test.log test.expected

test1: clean
	make run VCD=0 TEST_LOG=">> test.log"

#clean test log only when tests begin

sim-clean: iob-cache-hw-clean
	@rm -rf *.vcd

# AXI4 wrires
VHDR+=iob_cache_axi_wire.vh
iob_cache_axi_wire.vh:
	set -e; $(AXI_GEN) axi_wire $(BE_ADDR_W) $(BE_DATA_W) iob_cache_


.PHONY: waves test test1 sim-clean
