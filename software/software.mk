include $(CACHE_DIR)/core.mk

#SUBMODULES
ifneq (INTERCON,$(filter INTERCON, $(SUBMODULES)))
SUBMODULES+=INTERCON
INTERCON_DIR:=$(CACHE_DIR)/submodules/INTERCON
include $(INTERCON_DIR)/software/software.mk
endif

#INCLUDE
INCLUDE+=-I$(CACHE_DIR)/software

#HEADERS
HDR+=$(CACHE_SW_DIR)/iob-cache.h

#SOURCES
SRC+=$(CACHE_SW_DIR)/iob-cache.c

