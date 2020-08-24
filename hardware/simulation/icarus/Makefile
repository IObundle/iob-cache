#module paths
CACHE_DIR:=../../..

incdir:=-I
defmacro:=-D

include ../simulation.mk

#icarus verilog simulator
VLOG = 	iverilog -W all -g2005-sv

all: a.out
	./$< +vcd

a.out:	$(VSRC) $(VHDR)
	$(VLOG) $(INCLUDE) $(DEFINE) $(VSRC)

clean:
	@rm -f *# *~ *.vcd a.out *_tb

.PHONY: all clean
