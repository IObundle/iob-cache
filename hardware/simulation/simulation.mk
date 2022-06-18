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
	make run SIMULATOR=icarus BE_IF=iob && diff test1.expected test.log

TEST_LIST+=test2
test2:
	make run SIMULATOR=icarus BE_IF=axi && diff test2.expected test.log

TEST_LIST+=test3
test3:
	make run SIMULATOR=verilator BE_IF=iob && diff test3.expected test.log

TEST_LIST+=test4
test4:
	make run SIMULATOR=verilator BE_IF=axi && diff test4.expected test.log


.PHONY: test1 test2 test3 test4
