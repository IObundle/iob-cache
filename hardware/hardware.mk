# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment is used at setup-time in $(LIB_DIR)/Makefile
#
# It copies all hardware header and source files to $(BUILD_DIR)/hw
#
#


#import lib hardware
include hardware/regfile/iob_regfile_sp/hardware.mk
include hardware/fifo/iob_fifo_sync/hardware.mk
include hardware/ram/iob_ram_2p/hardware.mk
include hardware/ram/iob_ram_sp/hardware.mk


#HEADERS

#core headers
SRC+=$(subst $(CORE_DIR)/hardware/src, $(BUILD_VSRC_DIR), $(wildcard $(CORE_DIR)/hardware/src/*.vh) )
$(BUILD_VSRC_DIR)/%.vh: $(CORE_DIR)/hardware/src/%.vh
	cp $< $@

SRC+=$(BUILD_VSRC_DIR)/iob_gen_if.vh
$(BUILD_VSRC_DIR)/iob_gen_if.vh: hardware/include/iob_gen_if.vh
	cp $< $(BUILD_VSRC_DIR)

SRC+=$(BUILD_VSRC_DIR)/iob_lib.vh

AXI_GEN:=software/python/axi_gen.py
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


#cache software accessible register defines
SRC+=$(BUILD_VSRC_DIR)/iob_cache_swreg_def.vh
$(BUILD_VSRC_DIR)/iob_cache_swreg_def.vh: iob_cache_swreg_def.vh
	cp $< $@

iob_cache_swreg_def.vh: $(CORE_DIR)/mkregs.conf
	./software/python/mkregs.py $(NAME) $(CORE_DIR) HW

#SOURCES
SRC+=$(patsubst $(CORE_DIR)/hardware/src/%, $(BUILD_VSRC_DIR)/%, $(wildcard $(CORE_DIR)/hardware/src/*.v))
$(BUILD_VSRC_DIR)/%.v: $(CORE_DIR)/hardware/src/%.v
	cp $< $@
