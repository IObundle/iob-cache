include $(CACHE_DIR)/config.mk

USE_NETLIST ?=0

ifeq ($(USE_DDR),1)
#add itself to MODULES list
MODULES+=$(MODULE)

#import submodules hardware

#select modules to import from MEM
MEM_MODULES+=regfile/sp_reg_file fifo/sfifo ram/sp_ram

#include submodule's hardware
$(foreach p, $(SUBMODULES), $(if $(filter $p, $(MODULES)),,$(eval include $($p_DIR)/hardware/hardware.mk)))

#include
INCLUDE+=$(incdir)$(CACHE_INC_DIR)

#headers
VHDR+=$(wildcard $(CACHE_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(CACHE_SRC_DIR)/*.v)
endif
