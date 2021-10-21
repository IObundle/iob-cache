CORE_NAME:=CACHE
IS_CORE:=1
USE_NETLIST ?=0

#RTL simulator
CACHE_SIMULATOR:=icarus

#FPGA board
CACHE_FPGA_BOARD:=AES-KU040-DB-G

#paths
CACHE_SW_DIR:=$(CACHE_DIR)/software
CACHE_HW_DIR:=$(CACHE_DIR)/hardware
CACHE_INC_DIR:=$(CACHE_HW_DIR)/include
CACHE_SRC_DIR:=$(CACHE_HW_DIR)/src
CACHE_TB_DIR:=$(CACHE_HW_DIR)/testbench
CACHE_SIM_DIR:=$(CACHE_HW_DIR)/simulation/$(CACHE_SIMULATOR)
CACHE_FPGA_DIR:=$(CACHE_HW_DIR)/fpga/$(CACHE_FPGA_BOARD)
CACHE_SUBMODULES_DIR:=$(CACHE_DIR)/submodules

# SUBMODULES
CACHE_SUBMODULES:=MEM INTERCON AXIMEM
$(foreach p, $(CACHE_SUBMODULES), $(eval $p_DIR ?=$(CACHE_SUBMODULES_DIR)/$p))


#RULES
corename:
	@echo $(CORE_NAME)

.PHONY: corename
