include $(CACHE_DIR)/core.mk

#submodules
ifneq (INTERCON,$(filter INTERCON, $(SUBMODULES)))
SUBMODULES+=INTERCON
INTERCON_DIR:=$(CACHE_DIR)/submodules/INTERCON
include $(INTERCON_DIR)/hardware/hardware.mk
endif

ifneq (REGFILE,$(filter REGFILE, $(SUBMODULES)))
SUBMODULES+=REGFILE
REGFILE_DIR:=$(CACHE_DIR)/submodules/MEM/reg_file
VSRC+=$(REGFILE_DIR)/iob_reg_file.v
endif

ifneq (SFIFO,$(filter SFIFO, $(SUBMODULES)))
SUBMODULES+=SFIFO
SFIFO_DIR:=$(CACHE_DIR)/submodules/MEM/fifo/sfifo
VSRC+=$(SFIFO_DIR)/sfifo.v
endif

ifneq (BIN_COUNTER,$(filter BIN_COUNTER, $(SUBMODULES)))
SUBMODULES+=BIN_COUNTER
BIN_COUNTER_DIR:=$(CACHE_DIR)/submodules/MEM/fifo
VSRC+=$(BIN_COUNTER_DIR)/bin_counter.v
endif

ifneq ($(ASIC),1)
ifneq (SPRAM,$(filter SPRAM, $(SUBMODULES)))
SUBMODULES+=SPRAM
SPRAM_DIR:=$(CACHE_DIR)/submodules/MEM/sp_ram
VSRC+=$(SPRAM_DIR)/iob_sp_ram.v
endif

ifneq (2PRAM,$(filter 2PRAM, $(SUBMODULES)))
SUBMODULES+=2PRAM
2PRAM_DIR:=$(CACHE_DIR)/submodules/MEM/2p_ram
VSRC+=$(2PRAM_DIR)/iob_2p_ram.v
endif
endif

#include
CACHE_INC_DIR:=$(CACHE_HW_DIR)/include
INCLUDE+=$(incdir) $(CACHE_INC_DIR)

#headers
VHDR+=$(wildcard $(CACHE_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(CACHE_HW_DIR)/src/*.v)
