#module paths
CACHE_DIR:=../../../..
#testbench
VSRC+=$(CACHE_HW_DIR)/testbench/rep_pol_tb.v

incdir:=-I
defmacro:=-D


#core
include $(CACHE_DIR)/hardware/hardware.mk

#additional includes
INCLUDE+=$(incdir)$(CACHE_HW_DIR)/testbench/
VHDR+=$(CACHE_HW_DIR)/testbench/rep_pol_tb.vh

#additional defmacros
DEFINE+=$(defmacro)DATA_W=32 $(defmacro)ADDR_W=32

#icarus verilog simulator
VLOG = 	iverilog -W all -g2005-sv

all: a.out
	./$< +vcd

a.out:	$(VSRC) $(VHDR)
	$(VLOG) $(INCLUDE) $(DEFINE) $(VSRC)

clean:
	@rm -f *# *~ *.vcd a.out *_tb

.PHONY: all clean
