CORE := iob_cache
DISABLE_LINT:=1

all: sim-run

IOB_PYTHONPATH ?= ../../../iob_python
ifneq ($(PYTHONPATH),)
PYTHONPATH := $(IOB_PYTHONPATH):$(PYTHONPATH)
export PYTHONPATH
endif

PROJECT_ROOT=../..
LIB_DIR ?=../../lib
export LIB_DIR

BOARD ?= AES-KU040-DB-G

include $(LIB_DIR)/setup.mk


BE_IF ?= "AXI4"
SETUP_ARGS += BE_IF=$(BE_IF)

BE_DATA_W ?= "32"
SETUP_ARGS += BE_DATA_W=$(BE_DATA_W)

DOC ?= ug
SETUP_ARGS += DOC=$(DOC)

sim-build: clean
	$(call IOB_NIX_ENV, make build-setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ sim-build)

sim-run: clean
	$(call IOB_NIX_ENV, make build-setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W)  && make -C ../$(CORE)_V*/ sim-run)

sim-waves:
	$(call IOB_NIX_ENV, make -C ../$(CORE)_V*/ sim-waves"

sim-test: clean
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ sim-run SIMULATOR=icarus)
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ sim-run SIMULATOR=verilator)
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ sim-run SIMULATOR=icarus)
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ sim-run SIMULATOR=verilator)


fpga-build: clean
	$(call IOB_NIX_ENV, make build-setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ fpga-build FPGA_TOP=iob_cache_axi)

fpga-test: clean
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ fpga-build BOARD=AES-KU040-DB-G FPGA_TOP=iob_cache_iob)
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ fpga-build BOARD=AES-KU040-DB-G FPGA_TOP=iob_cache_axi)

doc-build: clean
	$(call IOB_NIX_ENV, make build-setup && make -C ../$(CORE)_V*/ doc-build DOC=$(DOC))

doc-view: ../$(CORE)_V*/document/$(DOC).pdf
	$(call IOB_NIX_ENV, make build-setup && make -C ../$(CORE)_V*/ doc-view DOC=$(DOC))

../$(CORE)_V*/document/$(DOC).pdf: doc-build

