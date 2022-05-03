CACHE_DIR:=../..
CORE_DIR:=$(CACHE_DIR)

NOCLEAN=-name "ug.pdf" -o -name "if.tex" -o -name "td.tex" \
	-o -name "swreg.tex" -o -name "swop.tex" -o -name "inst.tex" \
	-o -name "sim.tex" -o -name "synth.tex" -o -name "custom.tex" \
	-o -name "config.tex"

figures:
	mkdir -p ./figures
	cp -r -u $(LIB_DIR)/document/figures/* ../figures/* ./figures

include $(CACHE_DIR)/document/document.mk

