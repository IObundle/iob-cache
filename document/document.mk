include $(CACHE_DIR)/config.mk

#block diagram verilog source
BD_VSRC=iob-cache.v
CORENAME=CACHE

SWREGS=0

INTEL ?=1
INT_FAMILY ?=CYCLONEV-GT
XILINX ?=1
XIL_FAMILY ?=XCKU

NOCLEAN+=-o -name "test.expected" -o -name "Makefile"

#include tex submodule makefile segment
CORE_DIR:=$(CACHE_DIR)
include $(LIB_DIR)/document/document.mk

test: clean all
	diff -q $(DOC).aux test.expected

.PHONY: test
