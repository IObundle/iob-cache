CORE := iob_cache

all: sim-run

LIB_DIR=../../lib
PROJECT_ROOT=../..
BUILD_DIR=../$(CORE)_V*


CUSTOM_SHELL ?=nix-shell --run "$(1)"

# Pass 'py2hwsw' function to shell using workaround: https://stackoverflow.com/a/26518222
# The function is only needed for debug (when not using the version from nix-shell)
# To debug py2hwsw using a local version, you can override the 'py2hwsw' bin path using the following commands:
#   py2hwsw () { <path_to_custom_py2hwsw_repo>/py2hwsw/scripts/py2hwsw.py $@; }
#   export -f py2hwsw
BUILD_DIR ?= $(shell $(call CUSTOM_SHELL, py2hwsw='$(py2hwsw)' py2hwsw $(CORE) print_build_dir))

BE_IF ?= "AXI4"
SETUP_ARGS += BE_IF=$(BE_IF)
BE_DATA_W ?= "32"
SETUP_ARGS += BE_DATA_W=$(BE_DATA_W)

DOC ?= ug
SETUP_ARGS += DOC=$(DOC)

setup:
	$(call CUSTOM_SHELL, py2hwsw $(CORE) setup --project_root $(PROJECT_ROOT) --no_verilog_lint)
	# TODO: Somehow pass BE_IF and BE_DATA_W to `py_params_dict` argument of iob_cache.py
	#                   py2hwsw $(CORE) setup --project_root $(PROJECT_ROOT) BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W) --no_verilog_lint

sim-build: clean setup
	$(call CUSTOM_SHELL, make -C $(BUILD_DIR) sim-build)

sim-run: clean setup
	$(call CUSTOM_SHELL, make -C $(BUILD_DIR) sim-run)

sim-waves:
	$(call CUSTOM_SHELL, make -C $(BUILD_DIR) sim-waves)

sim-test: clean
	$(call CUSTOM_SHELL, make clean setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=icarus)
	$(call CUSTOM_SHELL, make clean setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=verilator)
	$(call CUSTOM_SHELL, make clean setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=icarus)
	$(call CUSTOM_SHELL, make clean setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) sim-run SIMULATOR=verilator)


fpga-build: clean
	$(call CUSTOM_SHELL, make setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) fpga-build FPGA_TOP=iob_cache_axi)

fpga-test: clean
	$(call CUSTOM_SHELL, make clean setup BE_IF=IOb BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) fpga-build BOARD=AES-KU040-DB-G FPGA_TOP=iob_cache_iob)
	$(call CUSTOM_SHELL, make clean setup BE_IF=AXI4 BE_DATA_W=$(BE_DATA_W) && make -C $(BUILD_DIR) fpga-build BOARD=AES-KU040-DB-G FPGA_TOP=iob_cache_axi)

doc-build: clean setup
	$(call CUSTOM_SHELL, make -C $(BUILD_DIR) doc-build DOC=$(DOC))

doc-view: ../$(CORE)_V*/document/$(DOC).pdf
	$(call CUSTOM_SHELL, make -C $(BUILD_DIR) doc-view DOC=$(DOC))

../$(CORE)_V*/document/$(DOC).pdf: doc-build

.PHONY: all setup sim-build sim-run sim-waves sim-test fpga-build fpga-test doc-build doc-view

clean:
	$(call CUSTOM_SHELL, py2hwsw $(CORE) clean --build_dir '$(BUILD_DIR)')
	@rm -rf ../*.summary ../*.rpt 
	@find . -name \*~ -delete
.PHONY: clean
