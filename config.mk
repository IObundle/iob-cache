TOP_MODULE=iob_cache

#PARAMETERS
DATA_W ?=32
ADDR_W ?=15
BE_DATA_W ?=64
BE_ADDR_W ?=24
NWAYS_W ?= 1
NLINES_W ?= 7
WORD_OFFSET_W ?= 3
WTBUF_DEPTH_W ?= 4
REP_POLICY ?=0
WRITE_POL ?= 0
CTRL_CACHE ?= 0
CTRL_CNT ?= 0

MACRO_LIST += DATA_W ADDR_W BE_DATA_W BE_ADDR_W NWAYS_W NLINES_W WORD_OFFSET_W WTBUF_DEPTH_W REP_POLICY WRITE_POL CTRL_CACHE CTRL_CNT

#PATHS
#paths that need disambiguation by prefix CACHE_
CACHE_HW_DIR:=$(CACHE_DIR)/hardware
CACHE_SW_DIR:=$(CACHE_DIR)/software

#paths that need no disambiguation
REMOTE_ROOT_DIR ?= sandbox/iob-cache
SIM_DIR ?=$(CACHE_HW_DIR)/simulation/$(SIMULATOR)
FPGA_DIR ?=$(shell find $(CACHE_DIR)/hardware -name $(FPGA_FAMILY))
DOC_DIR ?=$(CACHE_DIR)/document/$(DOC)

# submodule paths
LIB_DIR ?=$(CACHE_DIR)/submodules/LIB
MEM_DIR ?=$(CACHE_DIR)/submodules/MEM
AXI_DIR ?=$(CACHE_DIR)/submodules/AXI


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
$(TOP_MODULE)_version.txt:
ifeq ($(VERSION),)
	$(error "variable VERSION is not set")
endif
	echo $(VLINE) > version.txt

gen-clean:
	@rm -f *# *~

.PHONY: gen-clean
