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

build-clean: sim-clean fpga-clean doc-clean
	make -C $(LIB_DIR) clean-build-dir
	@rm -f hardware/src/$(TOP_MODULE).v


build-debug:
	make -C $(LIB_DIR) debug


#
# SIMULATE
#

SIM_DIR=$(BUILD_DIR)/sim
SIMULATOR?=icarus

sim-build: build-dir
	make -C $(SIM_DIR) build

sim-run: sim-build
	make -C $(SIM_DIR) run

sim-test:
	make -C $(SIM_DIR) test

sim-clean:
	if [ -f $(SIM_DIR)/Makefile ]; then make -C $(SIM_DIR) clean; fi

sim-debug: build-dir
	make -C $(SIM_DIR) debug

#
# FPGA
#

FPGA_DIR:=$(BUILD_DIR)/fpga
FPGA_FAMILY?=CYCLONEV-GT

fpga-build: build-dir
	make -C $(FPGA_DIR) build

fpga-run: build-build
	make -C $(FPGA_DIR) run

fpga-test:
	make -C $(FPGA_DIR) test

fpga-clean:
	if [ -f $(FPGA_DIR)/Makefile ]; then make -C $(FPGA_DIR) clean; fi

fpga-debug:
	make -C $(FPGA_DIR) debug

#
# DOCUMENT
#

DOC?=pb
DOC_DIR:=document/$(DOC)

doc-build:
	make -C $(DOC_DIR) $(DOC).pdf

doc-test:
	make -C $(DOC_DIR) test

doc-clean:
	make -C $(DOC_DIR) clean

doc-debug:
	make -C $(DOC_DIR) debug

#
# TEST
#

test-sim:
	make sim-test SIMULATOR=icarus
	make sim-test SIMULATOR=verilator

test-sim-clean:
	make sim-clean SIMULATOR=icarus
	make sim-clean SIMULATOR=verilator

test-fpga:
	make fpga-test FPGA_FAMILY=CYCLONEV-GT
	make fpga-test FPGA_FAMILY=XCKU

test-fpga-clean:
	make fpga-clean FPGA_FAMILY=CYCLONEV-GT
	make fpga-clean FPGA_FAMILY=XCKU

test-doc:
	make doc-test DOC=pb
	make doc-test DOC=ug

test-doc-clean:
	make doc-clean DOC=pb
	make doc-clean DOC=ug

test: test-clean test-sim test-fpga test-doc

test-clean: test-sim-clean test-fpga-clean test-doc-clean

clean: test-clean
	@rm -rf iob_cache_version.vh

debug:
	@echo $(VERSION_STR)

.PHONY: build-dir build-clean build-debug \
	sim-build sim-run sim-test sim-debug sim-clean \
	fpga-build fpga-run fpga-test fpga-clean fpga-debug \
	doc-build doc-test doc-clean doc-debug \
	test-sim test-sim-clean \
	test-fpga test-fpga-clean \
	test-doc test-doc-clean \
	test test-clean \
	clean debug

