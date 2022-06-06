#import hardware from submodules
include $(LIB_DIR)/hardware/regfile/iob_regfile_sp/hardware.mk
include $(LIB_DIR)/hardware/fifo/iob_fifo_sync/hardware.mk
include $(LIB_DIR)/hardware/ram/iob_ram_2p/hardware.mk
include $(LIB_DIR)/hardware/ram/iob_ram_sp/hardware.mk

#HEADERS

#core header
VHDR+=$(BUILD_VSRC_DIR)/iob_cache.vh
$(BUILD_VSRC_DIR)/iob_cache.vh: $(CACHE_DIR)/hardware/include/iob_cache.vh
	cp $< $(BUILD_VSRC_DIR)

#clk/rst interface
VHDR+=$(BUILD_VSRC_DIR)/iob_gen_if.vh
$(BUILD_VSRC_DIR)/iob_gen_if.vh: $(LIB_DIR)/hardware/include/iob_gen_if.vh
	cp $< $(BUILD_VSRC_DIR)

#back-end AXI4 interface verilog header file 
AXI_GEN:=$(LIB_DIR)/software/python/axi_gen.py
VHDR+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_port.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_port.vh:
	$(AXI_GEN) axi_m_port iob_cache_ && mv iob_cache_axi_m_port.vh $(BUILD_VSRC_DIR)

#back-end AXI4 portmap verilog header file 
VHDR+=$(BUILD_VSRC_DIR)/iob_cache_axi_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_portmap.vh:
	$(AXI_GEN) axi_portmap iob_cache_ && mv iob_cache_axi_portmap.vh $(BUILD_VSRC_DIR)

#SOURCES
VSRC1=$(wildcard $(CACHE_DIR)/hardware/src/*.v)
VSRC2=$(patsubst $(CACHE_DIR)/hardware/src/%, $(BUILD_VSRC_DIR)/%, $(VSRC1))

VSRC+=$(VSRC2)

$(VSRC2): $(VSRC1)
	cp $< $@
