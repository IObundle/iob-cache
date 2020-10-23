include $(CACHE_DIR)/core.mk

CACHE_SW_DIR:=$(CACHE_DIR)/software

#INCLUDE
INCLUDE+=-I$(CACHE_DIR)/software

#headers
HDR+=$(CACHE_SW_DIR)/iob-cache.h

#sources
SRC+=$(CACHE_SW_DIR)/iob-cache.c

