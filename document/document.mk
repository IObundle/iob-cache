# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment is used at build-time in $(BUILD_DIR)/doc/Makefile
#

#Set ASICSYNTH to 1 to include an ASIC synthesis section
ASICSYNTH?=0

#include implementation results if available
RESULTS = $(INTEL_FPGA)$(AMD_FPGA)$(UMC130_ASIC)

ifneq ($(wildcard quartus.tex),)
INTEL_FPGA = 1
endif

ifneq ($(wildcard vivado.tex),)
AMD_FPGA = 1
endif

ifneq ($(wildcard umc130.tex),)
UMC130_ASIC = 1
endif


#tests
TEST_LIST:=pb.pdf ug.pdf

.PHONY: $(TEST_LIST)
