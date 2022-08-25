#
# SIMULATION HARDWARE
#

# copy simulation wrapper
VSRC+=$(BUILD_SIM_DIR)/iob_cache_wrapper.v
$(BUILD_SIM_DIR)/iob_cache_wrapper.v: $(CORE_SIM_DIR)/iob_cache_wrapper.v
	cp $< $(BUILD_SIM_DIR)

# copy external memory for iob interface
include hardware/ram/iob_ram_sp_be/hardware.mk

# copy external memory for axi interface
include hardware/axiram/hardware.mk

# generate and copy AXI4 wires to connect cache to axi memory
VHDR+=$(BUILD_SIM_DIR)/iob_cache_axi_wire.vh
$(BUILD_SIM_DIR)/iob_cache_axi_wire.vh:
	./software/python/axi_gen.py axi_wire iob_cache_
	mv $(subst $(BUILD_SIM_DIR)/, , $@) $(BUILD_SIM_DIR)
