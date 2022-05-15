ifeq ($(filter CACHE, $(HW_MODULES)),)

include $(CACHE_DIR)/config.mk

CACHE_INC_DIR:=$(CACHE_HW_DIR)/include
CACHE_SRC_DIR:=$(CACHE_HW_DIR)/src

#add itself to HW_MODULES list
HW_MODULES+=CACHE

#import submodules hardware

#select mem modules to import
include $(MEM_DIR)/hardware/regfile/iob_regfile_sp/hardware.mk
include $(MEM_DIR)/hardware/fifo/iob_fifo_sync/hardware.mk
include $(MEM_DIR)/hardware/ram/iob_ram_2p/hardware.mk
include $(MEM_DIR)/hardware/ram/iob_ram_sp/hardware.mk

#include
INCLUDE+=$(incdir)$(CACHE_INC_DIR) $(incdir)$(LIB_DIR)/hardware/include

#headers
VHDR+=$(wildcard $(CACHE_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(CACHE_SRC_DIR)/*.v)

endif
