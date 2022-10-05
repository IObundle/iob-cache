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
SRC+=$(patsubst $(CACHE_DIR)/hardware/src, $(BUILD_VSRC_DIR), $(wildcard $(CACHE_DIR)/hardware/src/*))
$(BUILD_VSRC_DIR)/%: $(CACHE_DIR)/hardware/src/%
	cp $< $@

#generate axi headers
AXI_GEN:= $(LIB_DIR)/scripts/axi_gen.py

SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_port.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_port.vh:
	$(AXI_GEN) axi_m_port iob_cache_ && cp iob_cache_axi_m_port.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_ram_axi_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_ram_axi_portmap.vh:
	$(AXI_GEN) axi_portmap iob_cache_ram_ s_ && cp iob_cache_ram_axi_portmap.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_portmap.vh:
	$(AXI_GEN) axi_portmap iob_cache_ && cp iob_cache_axi_portmap.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_write_port.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_write_port.vh:
	$(AXI_GEN) axi_m_write_port iob_cache_m_ && cp iob_cache_m_axi_m_write_port.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_write_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_write_portmap.vh:
	$(AXI_GEN) axi_write_portmap iob_cache_m_ && cp iob_cache_m_axi_write_portmap.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_read_port.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_read_port.vh:
	$(AXI_GEN) axi_m_read_port iob_cache_m_ && cp iob_cache_m_axi_m_read_port.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_read_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_read_portmap.vh:
	$(AXI_GEN) axi_read_portmap iob_cache_m_ && cp iob_cache_m_axi_read_portmap.vh $(BUILD_VSRC_DIR)


#generate software accessible register
#note that this IP does not use the generated iob_cache_swreg_gen.vh as it provides this functionality itself
SRC+=$(BUILD_VSRC_DIR)/iob_cache_swreg_def.vh $(BUILD_VSRC_DIR)/iob_cache_swreg_gen.vh
$(BUILD_VSRC_DIR)/iob_cache_swreg_%.vh: iob_cache_swreg_%.vh
	cp $< $@

iob_cache_swreg_def.vh iob_cache_swreg_gen.vh: $(CACHE_DIR)/mkregs.conf
	$(LIB_DIR)/scripts/mkregs.py iob_cache $(CACHE_DIR) HW



