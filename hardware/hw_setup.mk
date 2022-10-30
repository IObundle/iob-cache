# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment is used at setup-time in $(LIB_DIR)/Makefile
#
# It copies all hardware header and source files to $(BUILD_DIR)/hw
#
#


#import lib hardware
include $(LIB_DIR)/hardware/include/hw_setup.mk
include $(LIB_DIR)/hardware/regfile/iob_regfile_sp/hw_setup.mk
include $(LIB_DIR)/hardware/fifo/iob_fifo_sync/hw_setup.mk
include $(LIB_DIR)/hardware/ram/iob_ram_2p/hw_setup.mk
include $(LIB_DIR)/hardware/ram/iob_ram_sp/hw_setup.mk

# copy verilog sources
SRC+=$(patsubst $(CACHE_DIR)/hardware/src/%, $(BUILD_VSRC_DIR)/%, $(wildcard $(CACHE_DIR)/hardware/src/*))
$(BUILD_VSRC_DIR)/%: $(CACHE_DIR)/hardware/src/%
	cp $< $@

#select core configuration
SRC+=$(BUILD_VSRC_DIR)/iob_cache_conf.vh
$(BUILD_VSRC_DIR)/iob_cache_conf.vh: $(CACHE_DIR)/hardware/src/iob_cache_conf_$(CACHE_CONFIG).vh
	cp $< $@

#generate axi headers
AXI_GEN:= $(LIB_DIR)/scripts/axi_gen.py

# generate axi ports
SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_port.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_port.vh:
	$(AXI_GEN) axi_m_port iob_cache_ && cp iob_cache_axi_m_port.vh $(BUILD_VSRC_DIR)

# generate portmap for axi instance
SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_m_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_m_portmap.vh:
	$(AXI_GEN) axi_m_m_portmap iob_cache_ && cp iob_cache_axi_m_m_portmap.vh $(BUILD_VSRC_DIR)

# generate axi write port for axi write module
SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_write_port.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_write_port.vh:
	$(AXI_GEN) axi_m_write_port iob_cache_ && cp iob_cache_axi_m_write_port.vh $(BUILD_VSRC_DIR)

# generate axi write portmap for axi write instance
SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_m_write_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_m_write_portmap.vh:
	$(AXI_GEN) axi_m_m_write_portmap iob_cache_ && cp iob_cache_axi_m_m_write_portmap.vh $(BUILD_VSRC_DIR)

# generate axi write port for axi read module
SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_read_port.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_read_port.vh:
	$(AXI_GEN) axi_m_read_port iob_cache_ && cp iob_cache_axi_m_read_port.vh $(BUILD_VSRC_DIR)

# generate axi write portmap for axi read module
SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_m_read_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_m_read_portmap.vh:
	$(AXI_GEN) axi_m_m_read_portmap iob_cache_ && cp iob_cache_axi_m_m_read_portmap.vh $(BUILD_VSRC_DIR)

# turn iob_cache_swreg_gen.v into an unused header as this core does not use it
SRC+=$(BUILD_VSRC_DIR)/iob_cache_swreg_gen.vh
$(BUILD_VSRC_DIR)/iob_cache_swreg_gen.vh: $(BUILD_VSRC_DIR)/iob_cache_swreg_gen.v
	mv $(BUILD_VSRC_DIR)/iob_cache_swreg_gen.v $(BUILD_VSRC_DIR)/iob_cache_swreg_gen.vh
