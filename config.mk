MODULE=CACHE
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
FPGA_DIR ?=$(shell find $($(MODULE)_DIR)/hardware -name $(FPGA_FAMILY))
DOC_DIR ?=$(CACHE_DIR)/document
SUBMODULES_DIR:=$(CACHE_DIR)/submodules

# submodule paths
SUBMODULES=
SUBMODULE_DIRS=$(shell ls $(SUBMODULES_DIR))
$(foreach d, $(SUBMODULE_DIRS), $(eval TMP=$(shell make -C $(SUBMODULES_DIR)/$d corename | grep -v make)) $(eval SUBMODULES+=$(TMP)) $(eval $(TMP)_DIR ?=$(SUBMODULES_DIR)/$d))

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
