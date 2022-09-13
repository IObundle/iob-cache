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
SRC+=$(BUILD_DIR)/sw/src/iob_cache_swreg.h
$(BUILD_DIR)/sw/src/iob_cache_swreg.h: $(CACHE_DIR)/mkregs.conf
	$(LIB_DIR)/software/python/mkregs.py iob_cache $(CACHE_DIR) SW
	mv `basename $@` $@ && mv iob_cache_swreg_emb.c $(BUILD_DIR)/sw/src/iob_cache_swreg_emb.c

# C header files
SRC+=$(patsubst $(CACHE_DIR)/software/%,$(BUILD_DIR)/sw/src/%, $(wildcard $(CACHE_DIR)/software/*.h))
$(BUILD_DIR)/sw/src/%.h: $(CACHE_DIR)/software/%.h
	cp $< $@

# C source files
SRC+=$(patsubst $(CACHE_DIR)/software/%,$(BUILD_DIR)/sw/src/%, $(wildcard $(CACHE_DIR)/software/*.c))
$(BUILD_DIR)/sw/src/%.c: $(CACHE_DIR)/software/%.c
	cp $< $@


#
# PC Emul Sources
#
SRC+=$(BUILD_DIR)/sw/pcsrc/iob_cache_swreg_pc_emul.c
$(BUILD_DIR)/sw/pcsrc/iob_cache_swreg_pc_emul.c: $(CACHE_DIR)/software/pc-emul/iob_cache_swreg_pc_emul.c
	cp $< $@

