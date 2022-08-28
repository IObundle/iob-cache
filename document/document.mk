#
# This file is included in BUILD_DIR/fpga/Makefile
#

# include core basic info
include ../../info.mk

#Set ASICSYNTH to 1 to include an ASIC synthesis section
ASICSYNTH?=0

#include implementation results; requires EDA tools
#default is 0 as EDA tools may not be accessible
RESULTS?=1
#default Intel FPGA family
INT_FAMILY ?=CYCLONEV-GT
#default Intel FPGA family
XIL_FAMILY ?=XCKU
#default ASIC node
#ASIC_NODE ?=UMC130

test: clean test1 test2

test1: pb.pdf
	diff -q $(DOC).aux pb_test.expected

test2: ug.pdf
	diff -q $(DOC).aux ug_test.expected

.PHONY: test
