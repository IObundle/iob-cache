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
test1: clean
	make run TEST_LOG=">> test.log"

.PHONY: test1
