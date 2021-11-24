#module paths
CACHE_DIR:=../../..

incdir:=-I
defmacro:=-D

SIMULATOR=icarus

include ../simulation.mk

#testbench
TB ?= $(CACHE_TB_DIR)/pipeline-iob-cache_tb.v
#TB ?=$(CACHE_TB_DIR)/rep_pol_tb.v

#icarus verilog simulator
VLOG = 	iverilog -W all -g2005-sv

run: a.out
	./$<
ifeq ($(VCD),1)
	if [ "`pgrep -u $(USER) gtkwave`" ]; then killall -q -9 gtkwave; fi
	gtkwave -a ../waves.gtkw uut.vcd &
endif

a.out: $(VSRC) $(VHDR)
	$(VLOG) $(INCLUDE) $(DEFINE) $(VSRC)

clean:
	@rm -f *# *~ *.vcd a.out *_tb

.PHONY: run clean
