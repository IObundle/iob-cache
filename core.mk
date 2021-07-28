#
# CORE DEFINITIONS FILE
#

CORE_NAME:=CACHE
IS_CORE:=1
USE_NETLIST ?=0
TOP_MODULE:=iob_cache

DATA_W ?=32

#paths
CACHE_HW_DIR:=$(CACHE_DIR)/hardware
CACHE_SW_DIR:=$(CACHE_DIR)/software
CACHE_DOC_DIR:=$(CACHE_DIR)/document
CACHE_SUBMODULES_DIR:=$(CACHE_DIR)/submodules
REMOTE_ROOT_DIR ?= sandbox/iob-soc/submodules/CACHE

#SUBMODULES
CACHE_SUBMODULES:=INTERCON MEM AXIMEM LIB TEX
$(foreach p, $(CACHE_SUBMODULES), $(eval $p_DIR ?=$(CACHE_SUBMODULES_DIR)/$p))

REGFILE_DIR ?=$(MEM_DIR)/reg_file
SFIFO_DIR ?=$(MEM_DIR)/fifo/sfifo
BIN_COUNTER_DIR ?=$(MEM_DIR)/fifo
SPRAM_DIR ?=$(MEM_DIR)/sp_ram
DPRAM_DIR ?=$(MEM_DIR)/dp_ram

#
#SIMULATION
#

#RTL simulator
SIMULATOR ?=icarus
SIM_DIR ?=$(CACHE_HW_DIR)/simulation/$(SIMULATOR)

#
#FPGA
#
FPGA_FAMILY ?=CYCLONEV-GT
FPGA_USER ?=$(USER)
FPGA_SERVER ?=pudim-flan.iobundle.com
ifeq ($(FPGA_FAMILY),XCKU)
	FPGA_COMP:=vivado
	FPGA_PART:=xcku040-fbva676-1-c
else #default; ifeq ($(FPGA_FAMILY),CYCLONEV-GT)
	FPGA_COMP:=quartus
	FPGA_PART:=5CGTFD9E5F35C7
endif
FPGA_DIR ?=$(CACHE_HW_DIR)/fpga/$(FPGA_COMP)
ifeq ($(FPGA_COMP),vivado)
FPGA_LOG ?=vivado.log
else ifeq ($(FPGA_COMP),quartus)
FPGA_LOG ?=quartus.log
endif

#ASIC
ASIC_NODE ?=umc130
ASIC_SERVER ?=micro5.lx.it.pt
ASIC_COMPILE_ROOT_DIR ?=$(ROOT_DIR)/sandbox/iob-cache
ASIC_USER ?=user14
ASIC_DIR ?=hardware/asic/$(ASIC_NODE)

#
#DOCUMENT
#
DOC_TYPE:=pb
#DOC_TYPE:=ug
INTEL ?=1
INT_FAMILY ?=CYCLONEV-GT
XILINX ?=1
XIL_FAMILY ?=XCKU
VERSION= 0.1
VLINE:="V$(VERSION)"
$(CORE_NAME)_version.txt:
ifeq ($(VERSION),)
	$(error "variable VERSION is not set")
endif
	echo $(VLINE) > version.txt
