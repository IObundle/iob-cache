ifeq ($(filter CACHE, $(HW_MODULES)),)

include $(CACHE_DIR)/config.mk

ifeq ($(USE_DDR),1)


USE_NETLIST ?=0

#add itself to HW_MODULES list
HW_MODULES+=CACHE

#import submodules hardware

#select modules to import from MEM
MEM_MODULES+=iob_regfile_sp iob_fifo_sync iob_ram_sp

#include submodule's hardware
$(foreach p, $(SUBMODULES_DIR_LIST), $(if $(filter $p, $(HW_MODULES)),,$(eval include $($p_DIR)/hardware/hardware.mk)))

#include
INCLUDE+=$(incdir)$(CACHE_INC_DIR)

#headers
VHDR+=$(wildcard $(CACHE_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(CACHE_SRC_DIR)/*.v)
endif
endif
