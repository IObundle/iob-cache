#
# This file is included in BUILD_DIR/fpga/Makefile
#

#Set ASICSYNTH to 1 to include an ASIC synthesis section
ASICSYNTH?=0

#include implementation results; requires EDA tools
#default is 0 as EDA tools may not be accessible
RESULTS ?= 1
#default Intel FPGA family
INT_FAMILY = CYCLONEV-GT
#default Intel FPGA family
XIL_FAMILY = XCKU
#default ASIC node
#ASIC_NODE ?=UMC130

#tests
TEST_LIST+=test1
test1: pb.pdf
	cat pb.aux >> test.log

TEST_LIST+=test2
test2: ug.pdf
	cat ug.aux >> test.log

.PHONY: $(TEST_LIST)
