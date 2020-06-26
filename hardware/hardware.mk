CACHE_HW_DIR:=$(CACHE_DIR)/hardware

#submodules
include $(INTERCON_DIR)/hardware/hardware.mk

#include
CACHE_INC_DIR:=$(CACHE_HW_DIR)/include
INCLUDE+=$(incdir) $(CACHE_INC_DIR)

#headers
VHDR+=$(CACHE_INC_DIR)/*.vh

#sources
CACHE_SRC_DIR:=$(CACHE_DIR)/hardware/src
VSRC+=$(CACHE_HW_DIR)/src/*.v \
$(AXI_MEM_DIR)/rtl/axi_ram.v \
$(MEM_DIR)/reg_file/iob_reg_file.v \
$(MEM_DIR)/fifo/afifo/afifo.v \
$(MEM_DIR)/sp_ram/iob_sp_mem.v
