include $(CACHE_DIR)/core.mk

#submodules
ifneq (INTERCON,$(filter INTERCON, $(SUBMODULES)))
SUBMODULES+=INTERCON
include $(INTERCON_DIR)/hardware/hardware.mk
endif

ifneq (REGFILE,$(filter REGFILE, $(SUBMODULES)))
SUBMODULES+=REGFILE
REGFILE_DIR:=$(MEM_DIR)/reg_file
VSRC+=$(REGFILE_DIR)/iob_reg_file.v
endif

ifneq (SFIFO,$(filter SFIFO, $(SUBMODULES)))
SUBMODULES+=SFIFO
SFIFO_DIR:=$(MEM_DIR)/fifo/sfifo
VSRC+=$(SFIFO_DIR)/sfifo.v
endif

ifneq (BIN_COUNTER,$(filter BIN_COUNTER, $(SUBMODULES)))
SUBMODULES+=BIN_COUNTER
BIN_COUNTER_DIR:=$(MEM_DIR)/fifo
VSRC+=$(BIN_COUNTER_DIR)/bin_counter.v
endif

ifneq ($(ASIC),1)
ifneq (SPRAM,$(filter SPRAM, $(SUBMODULES)))
SUBMODULES+=SPRAM
SPRAM_DIR:=$(MEM_DIR)/sp_ram
VSRC+=$(SPRAM_DIR)/iob_sp_ram.v
endif

ifneq (2PRAM,$(filter 2PRAM, $(SUBMODULES)))
SUBMODULES+=2PRAM
2PRAM_DIR:=$(MEM_DIR)/2p_ram
VSRC+=$(2PRAM_DIR)/iob_2p_ram.v
endif
endif

#include
INCLUDE+=$(incdir) $(CACHE_INC_DIR)

#headers
VHDR+=$(wildcard $(CACHE_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(CACHE_SRC_DIR)/*.v)
