CACHE_DIR:=../..

TAB=rs232_is_tab.tex cpu_nat_s_is_tab.tex cpu_axi4lite_s_is_tab.tex

NOCLEAN = -name "ug.pdf" -o -name "Makefile" -o -name "ifsignals.tex"

include $(CACHE_DIR)/document/document.mk

rs232_is_tab.tex: $(CACHE_HW_DIR)/src/iob-cache.v
	$(TEX_SW_DIR)/io2tex.py $< $@

