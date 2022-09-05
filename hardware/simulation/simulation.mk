#
# This file is included in BUILD_DIR/sim/Makefile
#


#generate testbench configuration file
VHDR+=iob_cache_tb_conf.vh
iob_cache_tb_conf.vh:
ifeq ($(TOP_MODULE),iob_cache_axi)
	../../sw/python/hw_defines.py $@ 'AXI=1'
else
	touch $@
endif

#verilator top module
VTOP:=iob_cache_wrapper

#tests
TEST_LIST+=test1
test1:
	make run SIMULATOR=icarus TOP_MODULE=iob_cache_iob

TEST_LIST+=test2
test2: test.log
	make clean SIMULATOR=icarus && make run SIMULATOR=icarus TOP_MODULE=iob_cache_axi

TEST_LIST+=test3
test3: test.log
	make clean SIMULATOR=verilator && make run SIMULATOR=verilator TOP_MODULE=iob_cache_iob

TEST_LIST+=test4
test4: test.log
	make clean SIMULATOR=verilator && make run SIMULATOR=verilator TOP_MODULE=iob_cache_axi

NOCLEAN+=-o -name "iob_cache_wrapper.v"
NOCLEAN+=-o -name "iob_cache_axi_wire.vh"
