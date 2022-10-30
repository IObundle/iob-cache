#
# SIMULATION HARDWARE
#

# copy iob memory
include $(LIB_DIR)/hardware/ram/iob_ram_sp_be/hw_setup.mk

# copy axi memory
include $(LIB_DIR)/hardware/axiram/hw_setup.mk

# generate portmap for axi memory model in simulation wrapper
SRC+=$(BUILD_VSRC_DIR)/iob_cache_ram_axi_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_ram_axi_portmap.vh: iob_cache_ram_axi_portmap.vh
	cp $< $@
iob_cache_ram_axi_portmap.vh:
	$(AXI_GEN) axi_portmap iob_cache_ram_ s_

# generate and copy AXI4 wires to connect cache to axi memory
SRC+=$(BUILD_SIM_DIR)/iob_cache_axi_wire.vh
$(BUILD_SIM_DIR)/iob_cache_axi_wire.vh: iob_cache_axi_wire.vh
	cp $< $@
iob_cache_axi_wire.vh:
	$(AXI_GEN) axi_wire iob_cache_

# generate portmap for simulation wrapper instance
SRC+=$(BUILD_VSRC_DIR)/iob_cache_axi_m_portmap.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_m_portmap.vh: iob_cache_axi_m_portmap.vh
	cp $< $@
iob_cache_axi_m_portmap.vh:
	$(AXI_GEN) axi_m_portmap iob_cache_

