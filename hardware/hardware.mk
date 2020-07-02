CACHE_HW_DIR:=$(CACHE_DIR)/hardware

#submodules
include $(INTERCON_DIR)/hardware/hardware.mk

#include
CACHE_INC_DIR:=$(CACHE_HW_DIR)/include
INCLUDE+=$(incdir) $(CACHE_INC_DIR)

#headers
VHDR+=$(wildcard $(CACHE_INC_DIR)/*.vh)

#sources
CACHE_SRC_DIR:=$(CACHE_DIR)/hardware/src
VSRC+=$(wildcard $(CACHE_HW_DIR)/src/*.v) \
$(MEM_DIR)/reg_file/iob_reg_file.v \
$(MEM_DIR)/fifo/afifo/afifo.v \
$(MEM_DIR)/sp_ram_be/iob_sp_ram_be.v \
$(MEM_DIR)/sp_ram/iob_sp_mem.v \
$(AXI_MEM_DIR)/rtl/axi_ram.v \
$(CACHE_HW_DIR)/wrapper/L2_ID_1sp.v
