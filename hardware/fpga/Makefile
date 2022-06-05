# root and lib paths
CORE_DIR:=../..
LIB_DIR:=$(CORE_DIR)/submodules/LIB

# core configuration
include $(CORE_DIR)/config.mk

#MODULE HARDWARE
CACHE_DIR:=../..
include $(CACHE_DIR)/hardware/hardware.mk

# fpga segment
TOP_MODULE:=iob_cache
include $(LIB_DIR)/hardware/fpga/fpga.mk

NOCLEAN:= -name 'Makefile' -o -name 'iob_cache.xdc' -o -name 'iob_cache.sdc' 

debug:
	@echo $(REMOTE_ROOT_DIR)
	@echo $(CORE_DIR)
	@echo $(CACHE_DIR)
	@echo $(VHDR)
	@echo $(VSRC)

.PHONY: debug
