# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment is used at build-time in $(BUILD_DIR)/doc/Makefile
#

#Set ASICSYNTH to 1 to include an ASIC synthesis section
ASICSYNTH?=0

#include implementation results; requires EDA tools
#default is 0 as EDA tools may not be accessible
RESULTS ?= 1

#default Intel FPGA family
ifeq ($(BOARD),CYCLONEV-GT-DK)
INTEL_FPGA = 1
endif

#default AMD FPGA family
ifeq ($(BOARD),AES-KU040-DB-G)
AMD_FPGA = 1
endif

#default ASIC node
#ASIC_NODE ?=UMC130

#tests
TEST_LIST:=pb.pdf ug.pdf

.PHONY: $(TEST_LIST)
