VCD ?=1

#defines
DEFINE+=$(defmacro)DATA_W=32 $(defmacro)ADDR_W=32

ifeq ($(VCD),1)
DEFINE+=$(defmacro)VCD
endif

include $(CACHE_DIR)/hardware/hardware.mk

#includes
INCLUDE+=$(incdir)$(CACHE_TB_DIR)

#headers
VHDR+=$(CACHE_TB_DIR)/iob-cache_tb.vh

#sources
#testbench
VSRC+=$(TB)
#other sources
VSRC+=$(AXIMEM_DIR)/rtl/axi_ram.v

waves:
	gtkwave uut.vcd

.PHONY: waves
