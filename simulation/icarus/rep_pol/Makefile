#file paths
ROOT_DIR := ../../..
RTL_DIR := $(ROOT_DIR)/rtl
SUBMODULES_DIR := $(ROOT_DIR)/submodules


#hw includes
HW_INCLUDE :=	-I. -I$(RTL_DIR)/testbench/ -I$(RTL_DIR)/include/ 


#icarus verilog simulator
VLOG = 	iverilog -W all -g2005-sv -DVCD

#hardware sources
VSRC :=	$(RTL_DIR)/testbench/rep_pol_tb.v $(RTL_DIR)/src/*.v  $(SUBMODULES_DIR)/iob-mem/sp_mem_be/iob_sp_mem_be.v	$(SUBMODULES_DIR)/iob-mem/afifo/afifo.v	$(SUBMODULES_DIR)/iob-mem/reg_file/iob_reg_file.v

all:	$(VSRC)
	$(VLOG) $(HW_INCLUDE)	-o rep_pol_tb $(VSRC)
	./rep_pol_tb +vcd

clean:
	@rm -f *# *~ *.vcd rep_pol

.PHONY: sim clean
