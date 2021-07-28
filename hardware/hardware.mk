include $(CACHE_DIR)/core.mk

#
# Cache submodules
#

# Interconnect
ifneq (INTERCON,$(filter INTERCON, $(SUBMODULES)))
SUBMODULES+=INTERCON
include $(INTERCON_DIR)/hardware/hardware.mk
endif

# Register file
ifneq (REGFILE,$(filter REGFILE, $(SUBMODULES)))
SUBMODULES+=REGFILE
VSRC+=$(REGFILE_DIR)/iob_reg_file.v
endif

# Synchronous FIFO
ifneq (SFIFO,$(filter SFIFO, $(SUBMODULES)))
SUBMODULES+=SFIFO
VSRC+=$(SFIFO_DIR)/sfifo.v
endif

# Binary counter
ifneq (BIN_COUNTER,$(filter BIN_COUNTER, $(SUBMODULES)))
SUBMODULES+=BIN_COUNTER
VSRC+=$(BIN_COUNTER_DIR)/bin_counter.v
endif

# Single-port RAM
ifneq (SPRAM,$(filter SPRAM, $(SUBMODULES)))
SUBMODULES+=SPRAM
VSRC+=$(SPRAM_DIR)/sp_ram.v
endif

# Dual-port RAM
ifneq (DPRAM,$(filter DPRAM, $(SUBMODULES)))
SUBMODULES+=DPRAM
VSRC+=$(DPRAM_DIR)/dp_ram.v
endif

# Lib
ifneq (LIB,$(filter LIB, $(SUBMODULES)))
SUBMODULES+=LIB
INCLUDE+=$(incdir) $(LIB_DIR)/hardware/include
VHDR+=$(wildcard $(LIB_DIR)/hardware/include/*.vh)
endif


#
# Cache Hardware
#

# Includes
INCLUDE+=$(incdir) $(CACHE_HW_DIR)/include

# Headers
VHDR+=$(wildcard $(CACHE_HW_DIR)/include/*.vh)

# Sources
VSRC+=$(wildcard $(CACHE_HW_DIR)/src/*.v)

#
# CPU accessible registers
#

$(CACHE_HW_DIR)/include/CACHEsw_reg_gen.v $(CACHE_HW_DIR)/include/CACHEsw_reg.vh: $(CACHE_HW_DIR)/include/CACHEsw_reg.v
	$(LIB_DIR)/software/mkregs.py $< HW
	mv CACHEsw_reg_gen.v $(CACHE_HW_DIR)/include
	mv CACHEsw_reg.vh $(CACHE_HW_DIR)/include

cache_clean_hw:
	@rm -rf $(CACHE_HW_DIR)/include/CACHEsw_reg_gen.v $(CACHE_HW_DIR)/include/CACHEsw_reg.vh tmp $(CACHE_HW_DIR)/fpga/vivado/XCKU $(CACHE_HW_DIR)/fpga/quartus/CYCLONEV-GT

.PHONY: cache_clean_hw
