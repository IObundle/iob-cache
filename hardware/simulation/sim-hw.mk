# add axi memory module
include $(LIB_DIR)/hardware/axiram/hardware.mk

# add AXI4 wires
VHDR+=$(BUILD_DIR)/sim/iob_cache_axi_wire.vh
$(BUILD_DIR)/sim/iob_cache_axi_wire.vh: iob_cache_axi_wire.vh
	mv $< $@

iob_cache_axi_wire.vh:
	./software/python/axi_gen.py axi_wire iob_cache_ 
