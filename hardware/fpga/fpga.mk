#
# This file is included in BUILD_DIR/fpga/Makefile
#

ifeq ($(TOP_MODULE),iob_cache_axi)
DEFINE=AXI
else
DEFINE=IOB
endif

#tests
TEST_LIST+=test1
test1:
	make build FPGA_FAMILY=CYCLONEV-GT TOP_MODULE=iob_cache_iob

TEST_LIST+=test2
test2: test.log
	make build FPGA_FAMILY=CYCLONEV-GT TOP_MODULE=iob_cache_axi

#TEST_LIST+=test3
test3: test.log
	make build FPGA_FAMILY=XCKU TOP_MODULE=iob_cache_iob

#TEST_LIST+=test4
test4: test.log
	make build FPGA_FAMILY=XCKU TOP_MODULE=iob_cache_axi
