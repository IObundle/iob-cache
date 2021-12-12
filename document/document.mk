include $(CACHE_DIR)/config.mk

#block diagram verilog source
BD_VSRC=iob-cache.v

INTEL ?=1
INT_FAMILY ?=CYCLONEV-GT
XILINX ?=1
XIL_FAMILY ?=XCKU

#include tex submodule makefile segment
CORE_DIR:=$(CACHE_DIR)
TEX_DIR ?=$($(MODULE)_SUBMODULES_DIR)/TEX
TEX_DOC_DIR ?=$(TEX_DIR)/document
include $(TEX_DOC_DIR)/document.mk
