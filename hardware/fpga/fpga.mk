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
	make clean && make build TOP_MODULE=iob_cache_iob
	cat *.tex > test.log

TEST_LIST+=test2
test2:
	make clean && make build TOP_MODULE=iob_cache_axi
	cat *.tex >> test.log


.PHONY: $(TEST_LIST)
