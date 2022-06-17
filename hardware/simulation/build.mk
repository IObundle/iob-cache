#
# This file segment is included in LIB_DIR/Makefile
#

# copy simulation wrapper
VSRC+=$(BUILD_SRC_DIR)/$(TOP_MODULE)_wrapper.v
$(BUILD_SRC_DIR)/$(TOP_MODULE)_wrapper.v: $(CORE_SIM_DIR)/$(TOP_MODULE)_wrapper.v
	cp $< $(BUILD_SRC_DIR)

# copy non-axi memory
include hardware/ram/iob_ram_sp_be/hardware.mk

# copy axi memory module
include hardware/axiram/hardware.mk

# add AXI4 wires
VHDR+=$(BUILD_SRC_DIR)/iob_cache_axi_wire.vh
$(BUILD_SRC_DIR)/iob_cache_axi_wire.vh:
	./software/python/axi_gen.py axi_wire iob_cache_
	mv $(subst $(BUILD_SRC_DIR)/, , $@) $(BUILD_SRC_DIR)

# add verilog top-level files
$(BUILD_SRC_DIR)/top:
	mkdir $@

VSRC+=$(BUILD_SRC_DIR)/top/$(TOP_MODULE)_axi.v $(BUILD_SRC_DIR)/top/$(TOP_MODULE)_iob.v

$(BUILD_SRC_DIR)/top/%.v: $(CORE_SRC_DIR)/top/%.v
	cp $< $@
