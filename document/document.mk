include $(CACHE_DIR)/config.mk

#RESULTS=1

INT_FAMILY ?=CYCLONEV-GT
XIL_FAMILY ?=XCKU

#include tex submodule makefile segment
#root directory
CORE_DIR:=$(CACHE_DIR)


#VHDR+=$(FPGA_DIR)/iob_cache_def.vh
VHDR+=axi_m_port.vh
VSRC+=$(CACHE_HW_DIR)/src/iob_cache_axi.v

#export definitions
export DEFINE

#VHDR+=$(PNG_D_HW_DIR)/include/iob_cache_config.vh

include $(LIB_DIR)/document/document.mk

NOCLEAN+=-o -name "test.expected" -o -name "Makefile"

test: clean $(DOC).pdf
	diff -q $(DOC).aux test.expected

.PHONY: test
