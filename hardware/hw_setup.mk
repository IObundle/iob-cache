# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment lists all hardware header and source files 
#
# It is always included in submodules/LIB/Makefile for populating the
# build directory
#
ifeq ($(filter CACHE, $(HW_MODULES)),)

#add itself to HW_MODULES list
HW_MODULES+=CACHE

#import lib hardware
include $(LIB_DIR)/hardware/include/hw_setup.mk
include $(LIB_DIR)/hardware/regfile/iob_regfile_sp/hw_setup.mk
include $(LIB_DIR)/hardware/fifo/iob_fifo_sync/hw_setup.mk
include $(LIB_DIR)/hardware/ram/iob_ram_2p/hw_setup.mk
include $(LIB_DIR)/hardware/ram/iob_ram_sp/hw_setup.mk

endif
