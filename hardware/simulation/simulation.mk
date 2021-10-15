include $(CACHE_DIR)/hardware/hardware.mk

#includes
INCLUDE+=$(incdir)$(CACHE_TB_DIR)

#headers
VHDR+=$(CACHE_TB_DIR)/iob-cache_tb.vh

#sources
VSRC+=$(CACHE_TB_DIR)/pipeline-iob-cache_tb.v \
$(AXIMEM_DIR)/rtl/axi_ram.v \
$(MEM_DIR)/sp_ram_be/iob_sp_ram_be.v
