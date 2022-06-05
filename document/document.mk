# root and lib paths
CORE_DIR:=../..
LIB_DIR:=$(CORE_DIR)/submodules/LIB

TOP_MODULE ?=iob_cache_axi

# core configuration
include $(CORE_DIR)/config.mk

VSRC+=$(CORE_DIR)/hardware/src/$(TOP_MODULE).v

include ../ug.mk

figures:
	mkdir -p ./figures
	cp -r -u $(LIB_DIR)/document/figures/* ../figures/* ./figures
ifeq ($(DOC),ug)
	cp -r -u $(LIB_DIR)/document/figures/* ../figures/bd.odg ./figures
endif


RESULTS=1

INT_FAMILY ?=CYCLONEV-GT
XIL_FAMILY ?=XCKU

TOP_MODULE ?=iob_cache_axi
include $(LIB_DIR)/document/document.mk

NOCLEAN+=-name "test.expected" -o -name "Makefile" -o -name "pb.pdf" -o -name "title.tex" -o -name "ug.pdf" -o -name "if.tex" -o -name "td.tex" -o -name "swreg.tex" -o -name "swop.tex" -o -name "inst.tex" -o -name "sim.tex" -o -name "synth.tex" -o -name "custom.tex" -o -name "config.tex" -o -name "revhist.tex"


test: clean $(DOC).pdf
	diff -q $(DOC).aux test.expected

debug:
	echo $(VHDR)
	echo $(VSRC)
	echo $(NOCLEAN)


.PHONY: test debug
