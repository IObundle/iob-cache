#module paths
CACHE_DIR:=../../..
incdir:=-I
defmacro:=-D

include $(CACHE_DIR)/hardware/hardware.mk

#headers
VHDR+=../testbench/iob-cache_tb.vh

#sources
VSRC+=$(AXIMEM_DIR)/rtl/axi_ram.v

INCLUDE=$(incdir)$(CACHE_INC_DIR)
INCLUDE+=$(incdir)../testbench

include $(MEM_DIR)/config.mk
$(foreach p, $(MEM_MODULES), $(eval include $(MEM_DIR)/hardware/$(p)/hardware.mk))

all: $(VSRC) testbench.cpp
	verilator -Wno-WIDTH --trace --cc --exe $(INCLUDE) $(VSRC) testbench.cpp --top-module iob_cache
	cd ./obj_dir && make -f Viob_cache.mk
	./obj_dir/Viob_cache

clean:
	rm -r ./obj_dir
	rm vcd.vcd

.PHONY: all clean