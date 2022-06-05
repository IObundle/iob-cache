ROOT_DIR:=.
include ./config.mk

#
# SIMULATE
#

SIM_DIR=hardware/simulation
sim-build:
	make -C $(SIM_DIR) build

sim-run:
	make -C $(SIM_DIR) run

sim-debug:
	make -C $(SIM_DIR) debug

sim-test:
	make -C $(SIM_DIR) test

sim-clean:
	make -C $(SIM_DIR) clean

#
# FPGA
#

FPGA_DIR:=hardware/fpga
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

debug:

clean: sim-clean fpga-clean doc-clean

update:
	find . -name .git -exec git co master \;
	find . -name .git -exec git pull origin master \;
	find . -name .git -exec git submodule update --init --recursive \;

.PHONY:	sim sim-test sim-clean \
	fpga-build fpga-test fpga-clean \
	doc-build doc-test doc-clean\
	test-sim test-sim-clean \
	test-fpga test-fpga-clean \
	test-doc test-doc-clean \
	test test-clean \
	clean debug update

