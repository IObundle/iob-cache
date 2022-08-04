#
# This file is included in BUILD_DIR/sim/Makefile
#

# include core basic info
include ../../info.mk

ifeq ($(TOP_MODULE),iob_cache_axi)
VFLAGS+=-DAXI
endif

#verilator top module
VTOP:=iob_cache_wrapper

# copy simulation wrapper
VSRC+=$(BUILD_VSRC_DIR)/iob_cache_wrapper.v
$(BUILD_VSRC_DIR)/iob_cache_wrapper.v: $(CORE_SIM_DIR)/iob_cache_wrapper.v
	cp $< $(BUILD_VSRC_DIR)

# copy external memory for iob interface
include hardware/ram/iob_ram_sp_be/hardware.mk

# copy external memory for axi interface
include hardware/axiram/hardware.mk

# generate and copy AXI4 wires to connect cache to axi memory
VHDR+=$(BUILD_VSRC_DIR)/iob_cache_axi_wire.vh
$(BUILD_VSRC_DIR)/iob_cache_axi_wire.vh:
	./software/python/axi_gen.py axi_wire iob_cache_
	mv $(subst $(BUILD_VSRC_DIR)/, , $@) $(BUILD_VSRC_DIR)

#tests
TEST_LIST+=test1
test1:
	make run SIMULATOR=icarus TOP_MODULE=iob_cache_iob

TEST_LIST+=test2
test2: test.log
	make run SIMULATOR=icarus TOP_MODULE=iob_cache_axi

TEST_LIST+=test3
test3: test.log
	make run SIMULATOR=verilator TOP_MODULE=iob_cache_iob

TEST_LIST+=test4
test4: test.log
	make run SIMULATOR=verilator TOP_MODULE=iob_cache_axi
