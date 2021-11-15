include $(CACHE_DIR)/config.mk

MODULES+=CACHE

#SUBMODULES
ifneq (INTERCON,$(filter INTERCON, $(MODULES)))
include $(INTERCON_DIR)/software/software.mk
endif

#INCLUDE
INCLUDE+=-I$(CACHE_DIR)/software

#HEADERS
HDR+=$(CACHE_SW_DIR)/iob-cache.h

#SOURCES
SRC+=$(CACHE_SW_DIR)/iob-cache.c

