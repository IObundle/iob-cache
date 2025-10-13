# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT

CORE := iob_cache

SIMULATOR ?= verilator
BOARD ?= iob_aes_ku040_db_g

BE_IF ?= AXI4

# Fill PY_PARAMS if not defined
ifeq ($(PY_PARAMS),)
ifneq ($(BE_IF),)
PY_PARAMS:=$(PY_PARAMS):be_if=$(BE_IF)
endif
ifneq ($(BE_DATA_W),)
PY_PARAMS:=$(PY_PARAMS):be_data_w=$(BE_DATA_W)
endif
# Remove first char (:) from PY_PARAMS
PY_PARAMS:=$(shell echo $(PY_PARAMS) | cut -c2-)
endif # ifndef PY_PARAMS

BUILD_DIR ?= $(shell nix-shell --run "py2hwsw $(CORE) print_build_dir --py_params '$(PY_PARAMS)'")
VERSION ?= $(shell nix-shell --run "py2hwsw $(CORE) print_core_version --py_params '$(PY_PARAMS)'")


DOC ?= ug

all: sim-run

setup:
	nix-shell --run "py2hwsw $(CORE) setup --no_verilog_lint --build_dir '$(BUILD_DIR)' --py_params '$(PY_PARAMS)' $(SETUP_ARGS)"

sim-build: clean setup
	nix-shell --run "make -C $(BUILD_DIR) sim-build SIMULATOR=$(SIMULATOR)"

sim-run: clean setup
	nix-shell --run "make -C $(BUILD_DIR) sim-run SIMULATOR=$(SIMULATOR)"

sim-waves:
	nix-shell --run "make -C $(BUILD_DIR) sim-waves"

sim-test: clean
	nix-shell --run "make clean setup BE_IF=IOb  && make -C $(BUILD_DIR) sim-run SIMULATOR=icarus"
	nix-shell --run "make clean setup BE_IF=IOb  && make -C $(BUILD_DIR) sim-run SIMULATOR=verilator"
	nix-shell --run "make clean setup BE_IF=AXI4 && make -C $(BUILD_DIR) sim-run SIMULATOR=icarus"
	nix-shell --run "make clean setup BE_IF=AXI4 && make -C $(BUILD_DIR) sim-run SIMULATOR=verilator"


fpga-build: clean
	nix-shell --run "make setup BE_IF=$(BE_IF) && make -C $(BUILD_DIR) fpga-build FPGA_TOP=iob_cache_axi BOARD=$(BOARD)"

fpga-test: clean
	nix-shell --run "make clean setup BE_IF=IOb && make -C $(BUILD_DIR) fpga-build BOARD=iob_aes_ku040_db_g FPGA_TOP=iob_cache_iob BOARD=$(BOARD)"
	nix-shell --run "make clean setup BE_IF=AXI4 && make -C $(BUILD_DIR) fpga-build BOARD=iob_aes_ku040_db_g FPGA_TOP=iob_cache_axi BOARD=$(BOARD)"

doc-build: clean setup
	nix-shell --run "make -C $(BUILD_DIR) doc-build DOC=$(DOC)"

doc-view: $(BUILD_DIR)/document/$(DOC).pdf
	nix-shell --run "make -C $(BUILD_DIR) doc-view DOC=$(DOC)"

$(BUILD_DIR)/document/$(DOC).pdf: doc-build

.PHONY: all setup sim-build sim-run sim-waves sim-test fpga-build fpga-test doc-build doc-view

clean:
	nix-shell --run "py2hwsw $(CORE) clean --build_dir '$(BUILD_DIR)'"
	@rm -rf ../*.summary ../*.rpt 
	@find . -name \*~ -delete

.PHONY: clean

# Release Artifacts

release-artifacts:
	nix-shell --run "make clean setup BE_IF=AXI4"
	tar -czf $(CORE)_axi_V$(VERSION).tar.gz ../$(CORE)_axi_V$(VERSION)
	nix-shell --run "make clean setup BE_IF=IOb"
	tar -czf $(CORE)_iob_V$(VERSION).tar.gz ../$(CORE)_iob_V$(VERSION)

.PHONY: release-artifacts
