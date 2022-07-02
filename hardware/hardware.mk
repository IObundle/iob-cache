ifeq ($(filter CACHE, $(HW_MODULES)),)

include $(CACHE_DIR)/config.mk

ifeq ($(USE_DDR),1)


USE_NETLIST ?=0

#add itself to HW_MODULES list
HW_MODULES+=CACHE

#import submodules hardware

#select mem modules to import
include $(MEM_DIR)/hardware/regfile/iob_regfile_sp/hardware.mk
include $(MEM_DIR)/hardware/fifo/iob_fifo_sync/hardware.mk
include $(MEM_DIR)/hardware/ram/iob_ram_2p/hardware.mk
include $(MEM_DIR)/hardware/ram/iob_ram_sp/hardware.mk

#include
INCLUDE+=$(incdir)$(CACHE_INC_DIR) $(incdir)$(LIB_DIR)/hardware/include

#headers
VHDR+=$(wildcard $(CACHE_INC_DIR)/*.vh)

VHDR+=m_axi_m_port.vh
m_axi_m_port.vh:
	$(LIB_DIR)/software/python/axi_gen.py axi_m_port 'm_' 'm_'

VHDR+=m_axi_portmap.vh
m_axi_portmap.vh:
	$(LIB_DIR)/software/python/axi_gen.py axi_portmap 'm_' 'm_' 'm_'


VHDR+=m_axi_m_write_port.vh
m_axi_m_write_port.vh:
	$(LIB_DIR)/software/python/axi_gen.py axi_m_write_port 'm_' 'm_'

VHDR+=m_axi_write_portmap.vh
m_axi_write_portmap.vh:
	$(LIB_DIR)/software/python/axi_gen.py axi_write_portmap 'm_' 'm_' 'm_'

VHDR+=m_axi_m_read_port.vh
m_axi_m_read_port.vh:
	$(LIB_DIR)/software/python/axi_gen.py axi_m_read_port 'm_' 'm_'

VHDR+=m_axi_read_portmap.vh
m_axi_read_portmap.vh:
	$(LIB_DIR)/software/python/axi_gen.py axi_read_portmap 'm_' 'm_' 'm_'


#sources
VSRC+=$(wildcard $(CACHE_SRC_DIR)/*.v)
endif
endif
