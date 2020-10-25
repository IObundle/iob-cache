include $(CACHE_DIR)/hardware/hardware.mk

#includes
INCLUDE+=$(incdir)$(CACHE_HW_DIR)/testbench/

#headers
VHDR+=$(CACHE_HW_DIR)/testbench/iob-cache_tb.vh

#sources
VSRC+=$(CACHE_HW_DIR)/testbench/pipeline-iob-cache_tb.v \
$(CACHE_DIR)/submodules/axi-mem/rtl/axi_ram.v \
$(CACHE_DIR)/submodules/iob-mem/sp_ram_be/iob_sp_ram_be.v \


