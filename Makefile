# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT

CORE := iob_cache

SIMULATOR := verilator

BOARD := aes_ku040_db_g

all: sim-run

BUILD_DIR ?= $(shell nix-shell --run "py2hwsw $(CORE) print_build_dir")

BE_IF ?= AXI4
BE_DATA_W ?= 32

DOC ?= ug

setup:
	nix-shell --run "py2hwsw $(CORE) setup --no_verilog_lint --py_params 'be_if=$(BE_IF):be_data_w=$(BE_DATA_W)'"

sim-build: clean setup
	nix-shell --run "make -C $(BUILD_DIR) sim-build SIMULATOR=$(SIMULATOR)"

sim-run: clean setup
	nix-shell --run "make -C $(BUILD_DIR) sim-run SIMULATOR=$(SIMULATOR)"

sim-waves:
	nix-shell --run "make -C $(BUILD_DIR) sim-waves"

sim-test: clean
	nix-shell --run "make clean setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=icarus"
	nix-shell --run "make clean setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=verilator"
	nix-shell --run "make clean setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=icarus"
	nix-shell --run "make clean setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=verilator"


fpga-build: clean
	nix-shell --run "make setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) fpga-build FPGA_TOP=iob_cache_axi BOARD=$(BOARD)"

fpga-test: clean
	nix-shell --run "make clean setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) fpga-build BOARD=aes_ku040_db_g FPGA_TOP=iob_cache_iob BOARD=$(BOARD)"
	nix-shell --run "make clean setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) fpga-build BOARD=aes_ku040_db_g FPGA_TOP=iob_cache_axi BOARD=$(BOARD)"

doc-build: clean setup
	nix-shell --run "make -C $(BUILD_DIR) doc-build DOC=$(DOC)"

doc-view: ../$(CORE)_V*/document/$(DOC).pdf
	nix-shell --run "make -C $(BUILD_DIR) doc-view DOC=$(DOC)"

../$(CORE)_V*/document/$(DOC).pdf: doc-build

.PHONY: all setup sim-build sim-run sim-waves sim-test fpga-build fpga-test doc-build doc-view

clean:
	nix-shell --run "py2hwsw $(CORE) clean --build_dir '$(BUILD_DIR)'"
	@rm -rf ../*.summary ../*.rpt 
	@find . -name \*~ -delete

.PHONY: clean
