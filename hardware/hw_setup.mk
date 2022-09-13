# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment is used at setup-time in $(LIB_DIR)/Makefile
#
# It copies all hardware header and source files to $(BUILD_DIR)/hw
#
#


#import lib hardware
include $(LIB_DIR)/hardware/include/hardware.mk
include $(LIB_DIR)/hardware/regfile/iob_regfile_sp/hardware.mk
include $(LIB_DIR)/hardware/fifo/iob_fifo_sync/hardware.mk
include $(LIB_DIR)/hardware/ram/iob_ram_2p/hardware.mk
include $(LIB_DIR)/hardware/ram/iob_ram_sp/hardware.mk


#HEADERS

#core headers

SRC+=$(subst $(CACHE_DIR)/hardware/src, $(BUILD_VSRC_DIR), $(wildcard $(CACHE_DIR)/hardware/src/*.vh) )
$(BUILD_VSRC_DIR)/%.vh: $(CACHE_DIR)/hardware/src/%.vh
	cp $< $@

SRC+=$(BUILD_VSRC_DIR)/iob_cache_version.vh
$(BUILD_VSRC_DIR)/iob_cache_version.vh:
	$(LIB_DIR)/software/python/version.py -v $(CACHE_DIR)
	mv iob_cache_version.vh $(BUILD_VSRC_DIR)

AXI_GEN:= $(LIB_DIR)/software/python/axi_gen.py
SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_port.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_port.vh:
	$(AXI_GEN) axi_m_port iob_cache_ && mv iob_cache_axi_m_port.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_portmap.vh:
	$(AXI_GEN) axi_portmap iob_cache_ && mv iob_cache_axi_portmap.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_write_port.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_write_port.vh:
	$(AXI_GEN) axi_m_write_port iob_cache_m_ && mv iob_cache_m_axi_m_write_port.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_write_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_write_portmap.vh:
	$(AXI_GEN) axi_write_portmap iob_cache_m_ && mv iob_cache_m_axi_write_portmap.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_read_port.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_read_port.vh:
	$(AXI_GEN) axi_m_read_port iob_cache_m_ && mv iob_cache_m_axi_m_read_port.vh $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_read_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_read_portmap.vh:
	$(AXI_GEN) axi_read_portmap iob_cache_m_ && mv iob_cache_m_axi_read_portmap.vh $(BUILD_VSRC_DIR)


#software accessible register defines
#note that this IP does not use the generated iob_cache_swreg_gen.vh as it provides this functionality itself
SRC+=$(BUILD_VSRC_DIR)/iob_cache_swreg_def.vh
$(BUILD_VSRC_DIR)/iob_cache_swreg_def.vh: $(CACHE_DIR)/mkregs.conf
	$(LIB_DIR)/software/python/mkregs.py iob_cache $(CACHE_DIR) HW
	mv `basename $@` $@ && rm iob_cache_swreg_gen.vh
