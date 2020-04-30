#file paths
ROOT_DIR := ../..
SUBMODULES_DIR := $(ROOT_DIR)/submodules
RTL_DIR := $(ROOT_DIR)/rtl

#hw includes
HW_INCLUDE :=	-I. -I$(RTL_DIR)/testbench/ -I$(RTL_DIR)/include/

#icarus verilog simulator
VLOG = 	iverilog -W all -g2005-sv -DVCD

#hardware sources
VSRC :=	$(RTL_DIR)/testbench/iob-cache_tb.v	$(RTL_DIR)/src/*.v	$(SUBMODULES_DIR)/iob-mem/sp_mem_be/iob_sp_mem_be.v	$(SUBMODULES_DIR)/iob-mem/afifo/afifo.v	$(SUBMODULES_DIR)/iob-mem/reg_file/iob_reg_file.v	$(SUBMODULES_DIR)/axi-mem/rtl/axi_ram.v

all:	$(VSRC)
	$(VLOG) $(HW_INCLUDE)	-o iob_cache_tb $(VSRC)
	./iob_cache_tb +vcd

clean:
	@rm -f *# *~ *.vcd iob*

.PHONY: sim clean
