# root and lib paths
CORE_DIR:=../..
LIB_DIR:=$(CORE_DIR)/submodules/LIB

# core configuration
include $(CORE_DIR)/config.mk

NOCLEAN=-name "ug.pdf" -o -name "if.tex" -o -name "td.tex" \
	-o -name "swreg.tex" -o -name "swop.tex" -o -name "inst.tex" \
	-o -name "sim.tex" -o -name "synth.tex" -o -name "custom.tex" \
	-o -name "config.tex"

figures:
	mkdir -p ./figures
	cp -r -u $(LIB_DIR)/document/figures/* ../figures/* ./figures

include ../document.mk

