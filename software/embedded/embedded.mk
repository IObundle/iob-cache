include $(CACHE_DIR)/software/software.mk

dummy:=BLA

#submodules
ifneq (MEM,$(filter M, $(LOCAL_SUBMODULES)))
include $(MEM_DIR)/software/embedded.mk
endif

ifneq (INTERCON,$(filter M, $(LOCAL_SUBMODULES)))
include $(INTERCON_DIR)/software/embedded.mk
endif

ifneq (AXIMEM,$(filter M, $(LOCAL_SUBMODULES)))
include $(AXIMEM_DIR)/software/embedded.mk
endif
