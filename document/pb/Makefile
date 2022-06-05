# root and lib paths
CORE_DIR:=../..
LIB_DIR:=$(CORE_DIR)/submodules/LIB

# core configuration
include $(CORE_DIR)/config.mk

NOCLEAN=-name "pb.pdf"

figures:
	mkdir -p ./figures
	cp -r -u $(LIB_DIR)/document/figures/* ../figures/bd.odg ./figures

include ../document.mk

