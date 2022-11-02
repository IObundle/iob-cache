#
# This file is included in BUILD_DIR/sim/Makefile
#

#generate testbench configuration file

#verilator top module
VTOP:=iob_cache_sim_wrapper

#tests
TEST_LIST+=test1
test1:
	make run SIMULATOR=icarus

TEST_LIST+=test2
test2: test.log
	make clean SIMULATOR=icarus && make run SIMULATOR=verilator

NOCLEAN+=-o -name "iob_cache_sim_wrapper.v"
NOCLEAN+=-o -name "axi_ram.v"
NOCLEAN+=-o -name "iob_cache_axi_wire.vh"
NOCLEAN+=-o -name "iob_cache_tb.cpp"
