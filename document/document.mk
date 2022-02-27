include $(CACHE_DIR)/config.mk

#block diagram verilog source
BD_VSRC=iob_cache.v

SWREGS=0

INT_FAMILY ?=CYCLONEV-GT
XIL_FAMILY ?=XCKU

ASIC_NODE=0

NOCLEAN+=-o -name "test.expected" -o -name "Makefile"

#include tex submodule makefile segment
#root directory
CORE_DIR:=$(CACHE_DIR)
#headers for creating tables
VHDR+=$(FPGA_DIR)/iob_cache_swreg_def.vh
VHDR+=$(CACHE_HW_DIR)/include/iob_cache_swreg.vh
VHDR+=$(LIB_DIR)/hardware/include/iob_s_if.vh
VHDR+=$(LIB_DIR)/hardware/include/gen_if.vh

#export definitions
export DEFINE

include $(LIB_DIR)/document/document.mk

test: clean $(DOC).pdf
	diff -q $(DOC).aux test.expected

.PHONY: test
