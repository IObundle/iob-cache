# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment lists all hardware header and source files 
#
# It is always included in submodules/LIB/Makefile for populating the
# build directory
#


#import lib hardware
include hardware/regfile/iob_regfile_sp/hardware.mk
include hardware/fifo/iob_fifo_sync/hardware.mk
include hardware/ram/iob_ram_2p/hardware.mk
include hardware/ram/iob_ram_sp/hardware.mk

#HEADERS

#core header
VHDR+=$(BUILD_SRC_DIR)/iob_cache.vh
$(BUILD_SRC_DIR)/iob_cache.vh: $(CACHE_DIR)/hardware/src/iob_cache.vh
	cp $< $(BUILD_SRC_DIR)

#clk/rst interface
VHDR+=$(BUILD_SRC_DIR)/iob_gen_if.vh
$(BUILD_SRC_DIR)/iob_gen_if.vh: hardware/include/iob_gen_if.vh
	cp $< $(BUILD_SRC_DIR)

#back-end AXI4 interface verilog header file 
AXI_GEN:=software/python/axi_gen.py
VHDR+=$(BUILD_SRC_DIR)/iob_cache_axi_m_port.vh
$(BUILD_SRC_DIR)/iob_cache_axi_m_port.vh:
	$(AXI_GEN) axi_m_port iob_cache_ && mv iob_cache_axi_m_port.vh $(BUILD_SRC_DIR)

#back-end AXI4 portmap verilog header file 
VHDR+=$(BUILD_SRC_DIR)/iob_cache_axi_portmap.vh
$(BUILD_SRC_DIR)/iob_cache_axi_portmap.vh:
	$(AXI_GEN) axi_portmap iob_cache_ && mv iob_cache_axi_portmap.vh $(BUILD_SRC_DIR)

#SOURCES
VSRC1=$(wildcard $(CACHE_DIR)/hardware/src/*.v)
VSRC2=$(patsubst $(CACHE_DIR)/hardware/src/%, $(BUILD_SRC_DIR)/%, $(VSRC1))
VSRC+=$(VSRC2)

$(BUILD_SRC_DIR)/%.v: $(CACHE_DIR)/hardware/src/%.v
	cp $< $@
