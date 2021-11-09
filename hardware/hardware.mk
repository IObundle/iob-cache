include $(CACHE_DIR)/core.mk

#submodules
ifneq (INTERCON,$(filter INTERCON, $(SUBMODULES)))
SUBMODULES+=INTERCON
include $(INTERCON_DIR)/hardware/hardware.mk
endif

# Single-port register file
include $(MEM_DIR)/regfile/sp_reg_file/hardware.mk

# Synchronous FIFO
include $(MEM_DIR)/fifo/sfifo/hardware.mk

# Single-port RAM
include $(MEM_DIR)/ram/sp_ram/hardware.mk

#include
INCLUDE+=$(incdir) $(CACHE_INC_DIR)

#headers
VHDR+=$(wildcard $(CACHE_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(CACHE_SRC_DIR)/*.v)
