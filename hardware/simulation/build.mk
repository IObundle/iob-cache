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

VSRC+=$(BUILD_SRC_DIR)/$(TOP_MODULE).v

TOP_ROOT=$(CORE_SRC_DIR)/top/$(TOP_MODULE)
TOP_CURR=$(CORE_SRC_DIR)/$(TOP_MODULE).v

$(TOP_CURR): swap-top

swap-top:
ifeq ($(BE_IF),axi)
	if [ ! -f $(TOP_CURR) ]; then cp $(TOP_ROOT)_axi.v $(TOP_CURR); elif [ "`diff -q $(TOP_ROOT)_axi.v $(TOP_CURR)`" ]; then cp $(TOP_ROOT)_axi.v $(TOP_CURR); fi
else
	if [ ! -f $(TOP_CURR) ]; then cp $(TOP_ROOT)_iob.v $(TOP_CURR); elif [ "`diff -q $(TOP_ROOT)_iob.v $(TOP_CURR)`" ]; then cp $(TOP_ROOT)_iob.v $(TOP_CURR); fi
endif

.PHONY: swap-top
