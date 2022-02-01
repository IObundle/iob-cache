TOP_MODULE=iob_cache

USE_DDR ?=1

#PATHS
#paths that need disambiguation by prefix CACHE_
CACHE_HW_DIR:=$(CACHE_DIR)/hardware
CACHE_INC_DIR:=$(CACHE_HW_DIR)/include
CACHE_SRC_DIR:=$(CACHE_HW_DIR)/src
CACHE_TB_DIR:=$(CACHE_HW_DIR)/testbench
CACHE_SW_DIR:=$(CACHE_DIR)/software

#paths that need no disambiguation
REMOTE_ROOT_DIR ?= sandbox/iob-soc/submodules/CACHE
SIM_DIR ?=$(CACHE_HW_DIR)/simulation/$(SIMULATOR)
FPGA_DIR ?=$(shell find $(CACHE_DIR)/hardware -name $(FPGA_FAMILY))
DOC_DIR ?=$(CACHE_DIR)/document

# submodule paths
SUBMODULES_DIR:=$(CACHE_DIR)/submodules
LIB_DIR ?=$(SUBMODULES_DIR_LIST)/LIB
MEM_DIR ?=$(SUBMODULES_DIR_LIST)/MEM

#DEFAULT SIMULATOR
SIMULATOR ?=icarus
SIMULATOR_LIST ?=icarus verilator

#DEFAULT FPGA FAMILY
FPGA_FAMILY ?=CYCLONEV-GT
FPGA_FAMILY_LIST ?=CYCLONEV-GT XCKU

#DEFAULT DOC
DOC ?=pb
DOC_LIST ?=pb ug

# VERSION
VERSION ?=0.1
VLINE ?="V$(VERSION)"
CACHE_version.txt:
ifeq ($(VERSION),)
	$(error "variable VERSION is not set")
endif
	echo $(VLINE) > version.txt

cache-gen-clean:
	@rm -f *# *~

.PHONY: cache-gen-clean
