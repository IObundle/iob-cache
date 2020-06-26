#core
include $(CACHE_DIR)/hardware/hardware.mk

#testbench
VSRC+=$(CACHE_HW_DIR)/testbench/iob-cache_tb.v \

#additional includes
INCLUDE+=$(incdir)$(CACHE_HW_DIR)/testbench/
VHDR+=$(CACHE_HW_DIR)/testbench/iob-cache_tb.vh

#additional defines
DEFINE+=$(define)DATA_W=32 $(define)ADDR_W=32
