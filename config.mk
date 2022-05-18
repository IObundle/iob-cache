TOP_MODULE=iob_cache

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


DATA_W ?=32
ADDR_W ?=32

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

cache-gen-clean:
	@rm -f *# *~

.PHONY: cache-gen-clean
