# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment lists all hardware header and source files 
#
# It is included in submodules/LIB/Makefile for populating the
# build directory
#


#import lib hardware
include hardware/regfile/iob_regfile_sp/hardware.mk
include hardware/fifo/iob_fifo_sync/hardware.mk
include hardware/ram/iob_ram_2p/hardware.mk
include hardware/ram/iob_ram_sp/hardware.mk


#HEADERS

#core headers
VHDR+=$(subst $(CACHE_DIR)/hardware/src, $(BUILD_VSRC_DIR), $(wildcard $(CACHE_DIR)/hardware/src/*.vh) )
$(BUILD_VSRC_DIR)/%.vh: $(CACHE_DIR)/hardware/src/%.vh
	cp $< $@

VHDR+=$(BUILD_VSRC_DIR)/iob_gen_if.vh
$(BUILD_VSRC_DIR)/iob_gen_if.vh: hardware/include/iob_gen_if.vh
	cp $< $(BUILD_VSRC_DIR)

VHDR+=$(BUILD_VSRC_DIR)/iob_lib.vh

AXI_GEN:=software/python/axi_gen.py
VHDR+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_port.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_port.vh:
	$(AXI_GEN) axi_m_port iob_cache_ && mv iob_cache_axi_m_port.vh $(BUILD_VSRC_DIR)

VHDR+=$(BUILD_VSRC_DIR)/iob_cache_axi_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_portmap.vh:
	$(AXI_GEN) axi_portmap iob_cache_ && mv iob_cache_axi_portmap.vh $(BUILD_VSRC_DIR)

VHDR+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_write_port.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_write_port.vh:
	$(AXI_GEN) axi_m_write_port iob_cache_m_ && mv iob_cache_m_axi_m_write_port.vh $(BUILD_VSRC_DIR)

VHDR+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_write_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_write_portmap.vh:
	$(AXI_GEN) axi_write_portmap iob_cache_m_ && mv iob_cache_m_axi_write_portmap.vh $(BUILD_VSRC_DIR)

VHDR+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_read_port.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_m_read_port.vh:
	$(AXI_GEN) axi_m_read_port iob_cache_m_ && mv iob_cache_m_axi_m_read_port.vh $(BUILD_VSRC_DIR)

VHDR+=$(BUILD_VSRC_DIR)/iob_cache_m_axi_read_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_m_axi_read_portmap.vh:
	$(AXI_GEN) axi_read_portmap iob_cache_m_ && mv iob_cache_m_axi_read_portmap.vh $(BUILD_VSRC_DIR)


#cache software accessible register defines
VHDR+=$(BUILD_VSRC_DIR)/iob_cache_swreg_def.vh
$(BUILD_VSRC_DIR)/iob_cache_swreg_def.vh: iob_cache_swreg_def.vh
	cp $< $@

iob_cache_swreg_def.vh: $(CACHE_DIR)/mkregs.conf
	$(MKREGS) $(NAME) $(CACHE_DIR) HW

#SOURCES
VSRC1=$(wildcard $(CACHE_DIR)/hardware/src/*.v)
VSRC2=$(patsubst $(CACHE_DIR)/hardware/src/%, $(BUILD_VSRC_DIR)/%, $(VSRC1))
VSRC+=$(VSRC2)

$(BUILD_VSRC_DIR)/%.v: $(CACHE_DIR)/hardware/src/%.v
	cp $< $@

#HW SOURCES AND HEADERS
HW_VHDR=$(VHDR)
HW_VSRC=$(VSRC)
