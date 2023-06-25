#
# This file is included in BUILD_DIR/sim/Makefile
#

#verilator top module
VTOP:=iob_cache_tb

#tests
TEST_LIST+=test1
test1:
	make run SIMULATOR=icarus


