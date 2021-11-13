#module paths
CACHE_DIR:=../..
incdir:=-I
defmacro:=-D

include $(CACHE_DIR)/hardware/hardware.mk

#defines
DEFINE+=$(defmacro)DATA_W=32 $(defmacro)ADDR_W=32
DEFINE+=$(defmacro)VCD


#includes
INCLUDE+=$(incdir) ./testbench

#headers
VHDR+=testbench/iob-cache_tb.vh

#sources
#testbench
TB ?= testbench/pipeline-iob-cache_tb.v
#TB ?=testbench/rep_pol_tb.v
VSRC+=$(TB)
#other sources
VSRC+=$(AXIMEM_DIR)/rtl/axi_ram.v


#icarus verilog simulator
VLOG = 	iverilog -W all -g2005-sv

run: a.out
	./$<
ifeq ($(VCD),1)
	if [ "`pgrep -u $(USER) gtkwave`" ]; then killall -q -9 gtkwave; fi
	gtkwave -a ../waves.gtkw uut.vcd &
endif

waves:
	gtkwave uut.vcd

a.out:	$(VSRC) $(VHDR)
	$(VLOG) $(INCLUDE) $(DEFINE) $(VSRC)

clean:
	@rm -f *# *~ *.vcd a.out *_tb

.PHONY: all clean
