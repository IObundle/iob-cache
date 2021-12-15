#module paths
CACHE_DIR:=../../..

incdir:=-I
defmacro:=-D

include ../simulation.mk

TB=testbench.cpp

run: $(VSRC) $(VHDR)
	verilator -Wno-WIDTH --trace --cc --exe $(INCLUDE) $(VSRC) --top-module $(TOP_MODULE)
	cd ./obj_dir && make -f V$(TOP_MODULE).mk
	./obj_dir/V$(TOP_MODULE) $(TEST_LOG)

clean: cache-gen-clean
	@rm -rf ./obj_dir

.PHONY: run clean
