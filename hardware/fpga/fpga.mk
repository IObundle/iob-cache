# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment is used at build-time in hardware/fpga/Makefile
#


ifeq ($(TOP_MODULE),iob_cache_axi)
DEFINE=AXI
else
DEFINE=IOB
endif

TEST_LIST+=test1
test1:
	make clean && make build TOP_MODULE=iob_cache_iob BOARD=CYCLONEV-GT-DK

#TEST_LIST+=test2
#test2:
#	make clean && make build TOP_MODULE=iob_cache_axi BOARD=CYCLONEV-GT-DK

#TEST_LIST+=test3
#test3:
#	make clean && make build TOP_MODULE=iob_cache_iob BOARD=AES-KU040-DB-

TEST_LIST+=test4
test4:
	make clean && make build TOP_MODULE=iob_cache_axi BOARD=AES-KU040-DB-G

.PHONY: $(TEST_LIST)
