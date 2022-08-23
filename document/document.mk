#
# This file is included in BUILD_DIR/fpga/Makefile
#

# include core basic info
include ../../info.mk

#Set ASICSYNTH to 1 to include an ASIC synthesis section
ASICSYNTH?=0

#include implementation results; requires FPGA tools
#default is 0 as FPGA tools may not be installed
RESULTS?=0

INT_FAMILY ?=CYCLONEV-GT
XIL_FAMILY ?=XCKU


test: clean test1 test2

test1: pb.pdf
	diff -q $(DOC).aux pb_test.expected

test2: ug.pdf
	diff -q $(DOC).aux ug_test.expected

.PHONY: test
