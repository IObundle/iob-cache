#
# This file segment is included in LIB_DIR/Makefile
#

# add axi memory module
include hardware/axiram/hardware.mk

# add AXI4 wires
VHDR+=$(BUILD_SRC_DIR)/iob_cache_axi_wire.vh

$(BUILD_SRC_DIR)/iob_cache_axi_wire.vh: iob_cache_axi_wire.vh
	mv $< $@

iob_cache_axi_wire.vh:
	./software/python/axi_gen.py axi_wire iob_cache_
