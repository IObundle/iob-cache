# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment  is used at setup-time in $(LIB_DIR)/Makefile
#
# It copies all software header and source files to $(BUILD_DIR)/sw
#


#
# Embedded sources
#

# sw accessible registers
SRC+=$(BUILD_SW_SRC_DIR)/iob_cache_swreg.h
$(BUILD_SW_SRC_DIR)/iob_cache_swreg.h: iob_cache_swreg.h
	pwd
	cp $< $@

SRC+=$(BUILD_SW_SRC_DIR)/iob_cache_swreg_emb.c
$(BUILD_SW_SRC_DIR)/iob_cache_swreg_emb.c: iob_cache_swreg_emb.c
	cp $< $@

iob_cache_swreg.h iob_cache_swreg_emb.c: $(CORE_DIR)/mkregs.conf
	./software/python/mkregs.py $(NAME) $(CORE_DIR) SW


HDR1=$(wildcard $(CORE_DIR)/software/*.h)
SRC+=$(patsubst $(CORE_DIR)/software/%,$(BUILD_SW_SRC_DIR)/%,$(HDR1))
$(BUILD_SW_SRC_DIR)/%.h: $(CORE_DIR)/software/%.h
	cp $< $@

SRC1=$(wildcard $(CORE_DIR)/software/*.c)
SRC+=$(patsubst $(CORE_DIR)/software/%,$(BUILD_SW_SRC_DIR)/%,$(SRC1))
$(BUILD_SW_SRC_DIR)/%.c: $(CORE_DIR)/software/%.c
	cp $< $@


#
# PC Emul Sources
#
SRC+=$(BUILD_SW_SRC_DIR)/iob_cache_swreg_pc_emul.c
$(BUILD_SW_SRC_DIR)/iob_cache_swreg_pc_emul.c: $(CORE_DIR)/software/pc-emul/iob_cache_swreg_pc_emul.c
	cp $< $@


