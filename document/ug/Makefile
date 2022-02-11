CACHE_DIR:=../..
CORE_DIR:=$(CACHE_DIR)

#interface signal tables
TAB=rs232_is_tab.tex iob_s_if_is_tab.tex

#include sowftware accessible registers
SWREGS=0

NOCLEAN=-name "ug.pdf" -o -name "ifsignals.tex" -o -name "sw_reg_tab.tex"

include $(CACHE_DIR)/document/document.mk

rs232_is_tab.tex: $(CACHE_HW_DIR)/src/iob-cache.v
	$(LIB_SW_PYTHON_DIR)/io2tex.py $< $@

