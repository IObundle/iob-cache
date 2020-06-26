#module paths
CACHE_DIR:=../../..
INTERCON_DIR:=$(CACHE_DIR)/submodules/iob-interconnect
MEM_DIR:=$(CACHE_DIR)/submodules/iob-mem
AXI_MEM_DIR:=$(CACHE_DIR)/submodules/axi-mem

incdir:=-I
define:=-D

include ../simulation.mk

#icarus verilog simulator
VLOG = 	iverilog -W all -g2005-sv

all: a.out
	./$< +vcd

a.out:	$(VSRC) $(VHDR)
	$(VLOG) $(INCLUDE) $(DEFINE) $(VSRC)

clean:
	@rm -f *# *~ *.vcd a.out

.PHONY: all clean
