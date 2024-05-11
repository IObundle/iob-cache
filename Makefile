CORE := iob_cache

DISABLE_LINT:=1
export DISABLE_LINT

all: sim-run

IOB_PYTHONPATH ?= ../../../iob_python
ifneq ($(PYTHONPATH),)
PYTHONPATH := $(IOB_PYTHONPATH):$(PYTHONPATH)
else
PYTHONPATH := $(IOB_PYTHONPATH)
endif
export PYTHONPATH

LIB_DIR=../../lib
export LIB_DIR

PROJECT_ROOT=../..
export PROJECT_ROOT

BUILD_DIR=../../../$(CORE)_build
export BUILD_DIR

BOARD ?= AES-KU040-DB-G


include $(LIB_DIR)/setup.mk



BE_IF ?= "AXI4"
SETUP_ARGS += BE_IF=$(BE_IF)
BE_DATA_W ?= "32"
SETUP_ARGS += BE_DATA_W=$(BE_DATA_W)

DOC ?= ug
SETUP_ARGS += DOC=$(DOC)

sim-build: clean
	$(call IOB_NIX_ENV, py2hwsw $(CORE) BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W))

sim-build: clean setup
	$(call IOB_NIX_ENV, make -C $(BUILD_DIR) sim-build)

sim-run: clean setup
	$(call IOB_NIX_ENV, make -C $(BUILD_DIR) sim-run)

sim-waves:
	$(call IOB_NIX_ENV, make -C $(BUILD_DIR) sim-waves)

sim-test: clean
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=icarus)
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=verilator)
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=icarus)
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=verilator)


fpga-build: clean
	$(call IOB_NIX_ENV, make build-setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) fpga-build FPGA_TOP=iob_cache_axi)

fpga-test: clean
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) fpga-build BOARD=AES-KU040-DB-G FPGA_TOP=iob_cache_iob)
	$(call IOB_NIX_ENV, make clean build-setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) fpga-build BOARD=AES-KU040-DB-G FPGA_TOP=iob_cache_axi)

doc-build: clean setup
	$(call IOB_NIX_ENV, make -C $(BUILD_DIR) doc-build DOC=$(DOC))

doc-view: ../$(CORE)_V*/document/$(DOC).pdf
	$(call IOB_NIX_ENV, make -C $(BUILD_DIR) doc-view DOC=$(DOC))

../$(CORE)_V*/document/$(DOC).pdf: doc-build

