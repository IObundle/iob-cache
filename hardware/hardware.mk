#import hardware from submodules
MEM_DIR:=$(CACHE_DIR)/submodules/LIB/hardware

include $(MEM_DIR)/regfile/iob_regfile_sp/hardware.mk
include $(MEM_DIR)/fifo/iob_fifo_sync/hardware.mk
include $(MEM_DIR)/ram/iob_ram_2p/hardware.mk
include $(MEM_DIR)/ram/iob_ram_sp/hardware.mk

#HEADERS

#main
VHDR+=iob_cache.vh
iob_cache.vh: $(CACHE_DIR)/hardware/include/iob_cache.vh
	cp $< $@

#configuration
iob_cache_conf.txt:
	$(foreach i, $(MACRO_LIST), echo "\`define $i $($i)" >> $@;)

VHDR+=iob_cache_conf.vh
iob_cache_conf.vh: iob_cache_conf.txt
	if [ ! -f $@ -o "`diff -q $@ $<`" ]; then mv $< $@; fi

#clk/rst interface
VHDR+=iob_gen_if.vh
iob_gen_if.vh: 	$(LIB_DIR)/hardware/include/iob_gen_if.vh
	cp $< $@

#back-end AXI4 interface verilog header file 
AXI_GEN:=$(LIB_DIR)/software/python/axi_gen.py
VHDR+=iob_cache_axi_m_port.vh
iob_cache_axi_m_port.vh:
	set -e; $(AXI_GEN) axi_m_port iob_cache_

#back-end AXI4 portmap verilog header file 
VHDR+=iob_cache_axi_portmap.vh
iob_cache_axi_portmap.vh:
	set -e; $(AXI_GEN) axi_portmap iob_cache_

#SOURCES
VSRC1=$(wildcard $(CACHE_DIR)/hardware/src/*.v)
VSRC2=$(foreach i, $(VSRC1), $(lastword $(subst /, ,$i)))
VSRC+=$(VSRC2)

$(VSRC2): $(VSRC1)
	cp $(CACHE_DIR)/hardware/src/$@ .
