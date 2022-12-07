# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment lists all software header and source files 
#
# It is used for populating the build directory
#

ifeq ($(filter CACHE, $(SW_MODULES)),)

#add itself to SW_MODULES list
SW_MODULES+=CACHE

# sw accessible registers C header and source files
# pc-emul sources
#SRC+=$(BUILD_PSRC_DIR)/iob_cache_swreg.h
#
#$(BUILD_PSRC_DIR)/iob_cache_swreg.h: iob_cache_swreg.h
#	cp $< $@
#
## embedded sources
#SRC+=$(BUILD_ESRC_DIR)/iob_cache_swreg.h $(BUILD_ESRC_DIR)/iob_cache_swreg_emb.c
#
#$(BUILD_ESRC_DIR)/iob_cache_swreg%: iob_cache_swreg%
#	mv $< $@
#
#iob_cache_swreg.h iob_cache_swreg_emb.c: $(CACHE_DIR)/mkregs.toml
#	$(LIB_DIR)/scripts/mkregs.py iob_cache $(CACHE_DIR) SW

endif
