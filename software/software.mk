MODULES+=CACHE

#SUBMODULES
ifneq (LIB,$(filter LIB, $(MODULES)))
include $(LIB_DIR)/software/software.mk
endif

#HEADERS
HDR+=iob_cache_swreg.h

#SOURCES
SRC+=iob_cache_swreg_emb.c

ifneq $($(MKREGS),)
	MKREGS:=$(shell find $(LIB_DIR) -name mkregs.py)
endif

iob_cache_swreg.h iob_cache_swreg_emb.c: $(CACHE_DIR)/mkregs.conf
	$(MKREGS) iob_cache $(CACHE_DIR) SW


