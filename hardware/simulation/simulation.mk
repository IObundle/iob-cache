#
# This file is included in BUILD_DIR/sim/Makefile
#

ifeq ($(TOP_MODULE),iob_cache_axi)
VFLAGS+=-DAXI
endif

#verilator top module
VTOP:=iob_cache_wrapper

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
