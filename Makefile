SHELL=/bin/bash
export

include config.mk

CACHE_DIR=../..
TOP_MODULE:=iob_cache

#
# CREATE BUILD DIRECTORY
#
#cache directory from LIB's perspective


BUILD_DIR := $(TOP_MODULE)_$(VERSION)

build-dir: $(BUILD_DIR)

$(BUILD_DIR):
	make -C submodules/LIB build-dir

clean:
	rm -rf $(BUILD_DIR)

debug:
	make -C submodules/LIB debug



#
# SIMULATE
#

SIM_DIR=$(BUILD_DIR)/sim
SIMULATOR?=icarus

sim-build: build-dir
	make -C $(SIM_DIR) build

sim-run: sim-build
	make -C $(SIM_DIR) run

sim-debug: build-dir
	make -C $(SIM_DIR) debug

sim-test:
	make -C $(SIM_DIR) test

sim-clean:
	make -C $(SIM_DIR) clean

#
# FPGA
#

FPGA_DIR:=$(BUILD_DIR)/fpga
FPGA_FAMILY?=CYCLONEV-GT
fpga-build:
	make -C $(FPGA_DIR) build

fpga-debug:
	make -C $(FPGA_DIR) debug

fpga-test:
	make -C $(FPGA_DIR) test

fpga-clean:
	make -C $(FPGA_DIR) clean

#
# DOCUMENT
#

DOC?=pb
DOC_DIR:=document/$(DOC)

doc-build:
	make -C $(DOC_DIR) $(DOC).pdf

doc-test:
	make -C $(DOC_DIR) test

doc-debug:
	make -C $(DOC_DIR) debug

doc-clean:
	make -C $(DOC_DIR) clean


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

.PHONY:	sim sim-test sim-clean \
	fpga-build fpga-test fpga-clean \
	doc-build doc-test doc-clean\
	test-sim test-sim-clean \
	test-fpga test-fpga-clean \
	test-doc test-doc-clean \
	test test-clean \
	clean debug

