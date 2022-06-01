#module paths
ROOT_DIR:=../../..
DUT_MODULE=iob_cache_wrapper

incdir:=-I
defmacro:=-D

include ../simulation.mk

TB=testbench.cpp
VSRC+=iob_cache_wrapper.v

VFLAGS=--cc --exe $(INCLUDE) $(DEFINE) $(VSRC) $(TB) --top-module $(DUT_MODULE)
WNO=-Wno-lint #Disable lint warnings
WAVE=--trace  #Generate waveforms

run: $(VSRC) $(VHDR)
	verilator $(VFLAGS) $(WNO) $(WAVE)	
	cd ./obj_dir && make -f V$(DUT_MODULE).mk
	./obj_dir/V$(DUT_MODULE) $(TEST_LOG)

clean: sim-clean
	@rm -rf ./obj_dir

.PHONY: run clean
