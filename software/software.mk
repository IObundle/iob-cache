# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment  is used at setup-time in $(LIB_DIR)/Makefile
#
# It copies all software header and source files to $(BUILD_DIR)/sw
#


#
# Embedded sources
#

# sw accessible registers C header and source files
SRC+=$(BUILD_SW_SRC_DIR)/iob_cache_swreg.h
$(BUILD_SW_SRC_DIR)/iob_cache_swreg.h: iob_cache_swreg.h
	pwd
	mv $< $@

SRC+=$(BUILD_SW_SRC_DIR)/iob_cache_swreg_emb.c
$(BUILD_SW_SRC_DIR)/iob_cache_swreg_emb.c: iob_cache_swreg_emb.c
	mv $< $@

iob_cache_swreg.h iob_cache_swreg_emb.c: $(CACHE_DIR)/mkregs.conf
	$(LIB_DIR)/software/python/mkregs.py iob_cache $(CACHE_DIR) SW

# C header files
HDR1=$(wildcard $(CACHE_DIR)/software/*.h)
SRC+=$(patsubst $(CACHE_DIR)/software/%,$(BUILD_SW_SRC_DIR)/%,$(HDR1))
$(BUILD_SW_SRC_DIR)/%.h: $(CACHE_DIR)/software/%.h
	cp $< $@

# C source files
SRC1=$(wildcard $(CACHE_DIR)/software/*.c)
SRC+=$(patsubst $(CACHE_DIR)/software/%,$(BUILD_SW_SRC_DIR)/%,$(SRC1))
$(BUILD_SW_SRC_DIR)/%.c: $(CACHE_DIR)/software/%.c
	cp $< $@


#
# PC Emul Sources
#
SRC+=$(BUILD_SW_PCSRC_DIR)/iob_cache_swreg_pc_emul.c
$(BUILD_SW_PCSRC_DIR)/iob_cache_swreg_pc_emul.c: $(CACHE_DIR)/software/pc-emul/iob_cache_swreg_pc_emul.c
	cp $< $@


