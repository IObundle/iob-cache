#
# This file is included in BUILD_DIR/fpga/Makefile
#

ifeq ($(BE_IF),axi)
DEFINE=AXI
else
DEFINE=IOB
endif

#tests
TEST_LIST+=test1
test1:
	make build FPGA_FAMILY=CYCLONEV-GT BE_IF=iob

TEST_LIST+=test2
test2: test.log
	make build FPGA_FAMILY=CYCLONEV-GT BE_IF=axi

#TEST_LIST+=test3
test3: test.log
	make build FPGA_FAMILY=XCKU BE_IF=iob

#TEST_LIST+=test4
test4: test.log
	make build FPGA_FAMILY=XCKU BE_IF=axi
