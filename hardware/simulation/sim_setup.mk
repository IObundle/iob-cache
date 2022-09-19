#
# SIMULATION HARDWARE
#

# copy external memory for iob interface
include $(LIB_DIR)/hardware/ram/iob_ram_sp_be/hw_setup.mk

# copy external memory for axi interface
include $(LIB_DIR)/hardware/axiram/hw_setup.mk

# generate and copy AXI4 wires to connect cache to axi memory
SRC+=$(BUILD_SIM_DIR)/iob_cache_axi_wire.vh
$(BUILD_SIM_DIR)/iob_cache_axi_wire.vh:
	$(LIB_DIR)/scripts/axi_gen.py axi_wire iob_cache_
	mv iob_cache_axi_wire.vh $(BUILD_SIM_DIR)

