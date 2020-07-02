#core
include $(CACHE_DIR)/hardware/hardware.mk

#testbench
VSRC+=$(CACHE_HW_DIR)/testbench/iob-cache_tb.v \
$(CACHE_HW_DIR)/wrapper/L2_ID_1sp.v \
$(AXI_MEM_DIR)/rtl/axi_ram.v 

#additional includes
INCLUDE+=$(incdir)$(CACHE_HW_DIR)/testbench/
VHDR+=$(CACHE_HW_DIR)/testbench/iob-cache_tb.vh

#additional defines
DEFINE+=$(define)DATA_W=32 $(define)ADDR_W=32
