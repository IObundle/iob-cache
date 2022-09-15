# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment is used at build-time in hardware/fpga/Makefile
#

TEST_LIST+=test1
test1:
	make clean && make build BOARD=CYCLONEV-GT-DK

TEST_LIST+=test2
test2:
	make clean && make build BOARD=AES-KU040-DB-G

.PHONY: $(TEST_LIST)
