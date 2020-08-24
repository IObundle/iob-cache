#core
include $(CACHE_DIR)/hardware/hardware.mk

#testbench
VSRC+=$(CACHE_HW_DIR)/testbench/iob-cache_tb.v \
$(CACHE_DIR)/submodules/axi-mem/rtl/axi_ram.v 
#$(CACHE_HW_DIR)/wrapper/L2_ID_1sp.v \

#additional includes
INCLUDE+=$(incdir)$(CACHE_HW_DIR)/testbench/
VHDR+=$(CACHE_HW_DIR)/testbench/iob-cache_tb.vh

#additional defmacros
DEFINE+=$(defmacro)DATA_W=32 $(defmacro)ADDR_W=32
