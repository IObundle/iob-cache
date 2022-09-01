# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment is used at build-time in $(BUILD_DIR)/hw/fpga/Makefile
#


ifeq ($(TOP_MODULE),iob_cache_axi)
DEFINE=AXI
else
DEFINE=IOB
endif

#tests
TEST_LIST+=test1
test1:
	make build FPGA_FAMILY=CYCLONEV-GT TOP_MODULE=iob_cache_iob && \
	cat quartus.tex >> test.log

TEST_LIST+=test2
test2:
	make build FPGA_FAMILY=XCKU TOP_MODULE=iob_cache_axi && \
	cat vivado.tex >> test.log


.PHONY: $(TEST_LIST)
