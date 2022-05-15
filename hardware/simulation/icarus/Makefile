CACHE_DIR:=../../..

incdir:=-I
defmacro:=-D

include ../simulation.mk

#testbench
TB ?= $(CACHE_TB_DIR)/iob-cache_tb.v
#TB ?=$(CACHE_TB_DIR)/rep_pol_tb.v

#icarus verilog simulator
VLOG = 	iverilog -W all -g2005-sv

.PHONY: run clean

run:
	$(VLOG) $(INCLUDE) $(DEFINE) $(VSRC)
	./a.out $(TEST_LOG)
ifeq ($(VCD),1)
	if [ "`pgrep -u $(USER) gtkwave`" ]; then killall -q -9 gtkwave; fi
	gtkwave -a ../waves.gtkw uut.vcd &
endif	

clean: cache-gen-clean
	@rm -f a.out
