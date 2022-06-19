#
# This file is included in BUILD_DIR/sim/Makefile
#

include ../hw-comp.mk

ifeq ($(BE_IF),axi)
VFLAGS+=-DAXI
endif

#verilator top module
VTOP:=iob_cache_wrapper

#tests
TEST_LIST+=test1
test1:
	make run SIMULATOR=icarus BE_IF=iob

TEST_LIST+=test2
test2: test.log
	make run SIMULATOR=icarus BE_IF=axi

TEST_LIST+=test3
test3: test.log
	make run SIMULATOR=verilator BE_IF=iob

TEST_LIST+=test4
test4: test.log
	make run SIMULATOR=verilator BE_IF=axi
