# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment lists all software header and source files 
#
# It is included in submodules/LIB/Makefile for populating the
# build directory
#

#
# Common Headers and Sources
#
#HEADERS
SRC+=$(BUILD_SW_SRC_DIR)/iob_cache_swreg.h
$(BUILD_SW_SRC_DIR)/iob_cache_swreg.h: iob_cache_swreg.h
	cp $< $@

HDR1=$(wildcard $(CACHE_DIR)/software/*.h)
SRC+=$(patsubst $(CACHE_DIR)/software/%,$(BUILD_SW_SRC_DIR)/%,$(HDR1))
$(BUILD_SW_SRC_DIR)/%.h: $(CACHE_DIR)/software/%.h
	cp $< $@

#SOURCES

SRC1=$(wildcard $(CACHE_DIR)/software/*.c)
SRC+=$(patsubst $(CACHE_DIR)/software/%,$(BUILD_SW_SRC_DIR)/%,$(SRC1))
$(BUILD_SW_SRC_DIR)/%.c: $(CACHE_DIR)/software/%.c
	cp $< $@

#
# Embedded Sources
#
SRC+=$(BUILD_SW_SRC_DIR)/iob_cache_swreg_emb.c
$(BUILD_SW_SRC_DIR)/iob_cache_swreg_emb.c: iob_cache_swreg_emb.c
	cp $< $@

#
# PC Emul Sources
#
SRC+=$(BUILD_SW_SRC_DIR)/iob_cache_swreg_pc_emul.c
$(BUILD_SW_SRC_DIR)/iob_cache_swreg_pc_emul.c: $(CACHE_DIR)/software/pc-emul/iob_cache_swreg_pc_emul.c
	cp $< $@

#MKREGS
iob_cache_swreg.h iob_cache_swreg_emb.c: $(CACHE_DIR)/mkregs.conf
	./software/python/mkregs.py $(NAME) $(CACHE_DIR) SW
