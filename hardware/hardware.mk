ifeq ($(filter CACHE, $(HW_MODULES)),)

include $(CACHE_DIR)/config.mk

#add itself to HW_MODULES list
HW_MODULES+=CACHE

#import hardware submodules
include $(MEM_DIR)/hardware/regfile/iob_regfile_sp/hardware.mk
include $(MEM_DIR)/hardware/fifo/iob_fifo_sync/hardware.mk
include $(MEM_DIR)/hardware/ram/iob_ram_2p/hardware.mk
include $(MEM_DIR)/hardware/ram/iob_ram_sp/hardware.mk

#HEADERS
#cache
VHDR+=iob_cache.vh
iob_cache.vh:
	cp $(CACHE_HW_DIR)/include/iob_cache.vh .
#configuration
VHDR+=iob_cache_conf.vh
iob_cache_conf.vh:
	$(foreach i, $(MACRO_LIST), echo "\`define $i $($i)" >> $@;)
#lib
VHDR+=iob_lib.vh
iob_lib.vh:
	cp $(LIB_DIR)/hardware/include/$@ .
#clk/rst interface
VHDR+=gen_if.vh
gen_if.vh:
	cp $(LIB_DIR)/hardware/include/$@ .

#back-end interface
VHDR+=axi_m_port.vh
AXI_GEN:=$(AXI_DIR)/software/axi_gen.py
axi_m_port.vh:
	set -e; $(AXI_GEN) axi_m_port $(BE_ADDR_W) $(BE_DATA_W)

#SOURCES
VSRC+=$(wildcard $(CACHE_HW_DIR)/src/*.v)

clean-testlog:
	@rm -f test.log

clean-all: clean-testlog clean

hw-clean: gen-clean
	@rm -f *.vh 

.PHONY: clean-testlog clean-all hw-clean

endif
