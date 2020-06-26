CACHE_SW_DIR:=$(CACHE_DIR)/software

#include
INCLUDE+=-I$(CACHE_DIR)/software

#headers
HDR+=$(CACHE_SW_DIR)/iob-cache.h

#sources
SRC+=$(CACHE_SW_DIR)/iob-cache.c

