include $(CACHE_DIR)/config.mk

ifneq (CACHE,$(filter CACHE, $(MODULES)))

MODULES+=CACHE

#SUBMODULES
include $(LIB_DIR)/software/software.mk

#INCLUDE
INCLUDE+=-I$(CACHE_DIR)/software

#HEADERS
HDR+=$(CACHE_SW_DIR)/iob-cache.h

#SOURCES
SRC+=$(CACHE_SW_DIR)/iob-cache.c

endif
