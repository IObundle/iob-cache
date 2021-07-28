CACHE_DIR:=../..
include $(CACHE_DIR)/core.mk

IS_TAB:=gen_is_tab.tex cpu_nat_s_is_tab.tex cpu_axi4lite_s_is_tab.tex rs232_is_tab.tex

REG_TAB:=sw_reg_tab.tex

BD_TAB:=bd_tab.tex

SRC:=ug.tex $(wildcard ./*.tex) $(wildcard ../*.tex)  $(IS_TAB) $(REG_TAB) $(BD_TAB)

TD_FIGS:= #list figures here

include $(CACHE_DIR)/submodules/TEX/document/document.mk

bd_tab.tex: $(CACHE_HW_DIR)/src/iob_cache.v
	$(TEX_SW_DIR)/block2tex.py $@ $^

rs232_is_tab.tex: $(CACHE_HW_DIR)/src/iob_cache.v
	$(TEX_SW_DIR)/io2tex.py $< $@

clean: texclean
	@rm -f $(IS_TAB) $(REG_TAB) $(BD_TAB)

.PHONY: clean
