# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment  is used at setup-time in $(LIB_DIR)/Makefile
#
# It copies all software header and source files to $(BUILD_DIR)/sw
#

# sw accessible registers C header and source files
SRC+=$(BUILD_ESRC_DIR)/iob_cache_swreg.h $(BUILD_ESRC_DIR)/iob_cache_swreg_emb.c

$(BUILD_ESRC_DIR)/iob_cache_swreg%: iob_cache_swreg%
	mv $< $@

iob_cache_swreg.h iob_cache_swreg_emb.c: $(CACHE_DIR)/mkregs.conf
	$(LIB_DIR)/scripts/mkregs.py iob_cache $(CACHE_DIR) SW

