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
NAME ?= $(shell nix-shell --run "py2hwsw $(CORE) print_core_name --py_params '$(PY_PARAMS)'")
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

sim-test:
	make sim-run SIMULATOR=icarus BE_IF=IOb
	make sim-run SIMULATOR=verilator BE_IF=IOb
	make sim-run SIMULATOR=icarus BE_IF=AXI4
	make sim-run SIMULATOR=verilator BE_IF=AXI4

lint: clean setup
	nix-shell --run "make -C $(BUILD_DIR)/hardware/lint run"

lint-test:
	make lint BE_IF=IOb
	make lint BE_IF=AXI4

fpga-build: clean setup
	nix-shell --run "make -C $(BUILD_DIR) fpga-build FPGA_TOP=$(NAME) BOARD=$(BOARD)"

fpga-test:
	make fpga-build BE_IF=IOb
	make fpga-build BE_IF=AXI4


syn-build: clean setup
	nix-shell --run "make -C $(BUILD_DIR) syn-build"

syn-test:
	make syn-build BE_IF=IOb
	make syn-build BE_IF=AXI4

doc-build: clean setup
	nix-shell --run "make -C $(BUILD_DIR) doc-build DOC=$(DOC)"

doc-view: $(BUILD_DIR)/document/$(DOC).pdf
	nix-shell --run "make -C $(BUILD_DIR) doc-view DOC=$(DOC)"

$(BUILD_DIR)/document/$(DOC).pdf: doc-build

.PHONY: all setup sim-build sim-run sim-waves sim-test fpga-build fpga-test doc-build doc-view

clean:
	nix-shell --run "py2hwsw $(CORE) clean --build_dir '$(BUILD_DIR)'"
	@rm -rf ../*.summary ../*.rpt fusesoc_exports *.core
	@find . -name \*~ -delete

.PHONY: clean

fusesoc-export: clean setup
	nix-shell --run "py2hwsw $(CORE) export_fusesoc --build_dir '$(BUILD_DIR)' --py_params '$(PY_PARAMS)'"

.PHONY: fusesoc-export

CORE_NAME=$(shell nix-shell --run "py2hwsw $(CORE) print_core_name --py_params '$(PY_PARAMS)'")

define MULTILINE_TEXT
provider:
  name: url
  url: https://github.com/IObundle/iob-cache/releases/latest/download/$(CORE_NAME)_V$(VERSION).tar.gz
  filetype: tar
endef

# Generate independent fusesoc .core file. FuseSoC will obtain the Verilog sources from remote url with a pre-built build directory.
export MULTILINE_TEXT
fusesoc-core-file: fusesoc-export
	cp fusesoc_exports/$(CORE_NAME).core .
	# Append provider remote URL to .core file
	printf "\n%s\n" "$$MULTILINE_TEXT" >> $(CORE_NAME).core
	echo "Generated independent $(CORE_NAME).core file."

.PHONY: fusesoc-core-file

# Release Artifacts

release-artifacts:
	make fusesoc-export BE_IF=AXI4
	tar -czf $(CORE)_axi_V$(VERSION).tar.gz -C ./fusesoc_exports .
	make fusesoc-export BE_IF=IOb
	tar -czf $(CORE)_iob_V$(VERSION).tar.gz -C ./fusesoc_exports .

.PHONY: release-artifacts
