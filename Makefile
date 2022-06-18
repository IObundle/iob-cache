SHELL:=/bin/bash
export

include info.mk

#
# BUILD DIRECTORY
#

VERSION_STR=$(shell $(LIB_DIR)/software/python/version.py $(TOP_MODULE) $(VERSION))
BUILD_DIR = $(TOP_MODULE)_$(VERSION_STR)
LIB_DIR=submodules/LIB
build-dir:
	make -C $(LIB_DIR) build-dir

build-clean:
	make -C $(LIB_DIR) clean

build-debug:
	make -C $(LIB_DIR) debug


#
# SIMULATE
#

SIM_DIR=$(BUILD_DIR)/sim
sim-build: build-dir
	make -C $(SIM_DIR) build

sim-run: sim-build
	make -C $(SIM_DIR) run

sim-test: build-dir
	make -C $(SIM_DIR) test

sim-clean: build-dir
	make -C $(SIM_DIR) clean

sim-debug: build-dir
	make -C $(SIM_DIR) debug

#
# FPGA
#

FPGA_DIR:=$(BUILD_DIR)/fpga
fpga-build: build-dir
	make -C $(FPGA_DIR) build

fpga-run: build-build
	make -C $(FPGA_DIR) run

fpga-test: build-build
	make -C $(FPGA_DIR) test

fpga-clean: build-build
	make -C $(FPGA_DIR) clean; fi

fpga-debug: build-dir
	make -C $(FPGA_DIR) debug

#
# DOCUMENT
#

DOC_DIR:=$(BUILD_DIR)/doc
doc-build: build-dir
	make -C $(DOC_DIR) $(DOC).pdf

doc-test: build-build
	make -C $(DOC_DIR) test

doc-clean: build-build
	make -C $(DOC_DIR) clean

doc-debug: build-dir
	make -C $(DOC_DIR) debug

#
# TEST
#

test: build-clean sim-test fpga-test doc-test

#
# DEBUG: add makefile variables here for debugging
#

debug:
	@echo $(VERSION_STR)


.PHONY: build-dir build-clean build-debug \
	sim-build sim-run sim-test sim-debug sim-clean \
	fpga-build fpga-test fpga-clean fpga-debug \
	doc-build doc-test doc-clean doc-debug \
	test debug

