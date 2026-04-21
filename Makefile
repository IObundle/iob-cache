# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT

CORE := iob_cache

SIMULATOR ?= verilator
BOARD ?= iob_aes_ku040_db_g

FE_IF ?= IOb
BE_IF ?= AXI4

# Fill PY_PARAMS if not defined
ifeq ($(PY_PARAMS),)
ifneq ($(FE_IF),)
PY_PARAMS:=$(PY_PARAMS):fe_if=$(FE_IF)
endif
ifneq ($(BE_IF),)
PY_PARAMS:=$(PY_PARAMS):be_if=$(BE_IF)
endif
ifneq ($(BE_DATA_W),)
PY_PARAMS:=$(PY_PARAMS):be_data_w=$(BE_DATA_W)
endif
ifneq ($(USE_CTRL),)
PY_PARAMS:=$(PY_PARAMS):use_ctrl=$(USE_CTRL)
endif
ifneq ($(WRITE_POL),)
PY_PARAMS:=$(PY_PARAMS):write_pol=$(WRITE_POL)
endif
ifneq ($(NWAYS_W),)
PY_PARAMS:=$(PY_PARAMS):nways_w=$(NWAYS_W)
endif
# Remove first char (:) from PY_PARAMS
PY_PARAMS:=$(shell echo $(PY_PARAMS) | cut -c2-)
endif # ifndef PY_PARAMS

BUILD_DIR ?= $(shell nix-shell --run "py2hwsw $(CORE) print_build_dir --py_params '$(PY_PARAMS)'")
NAME ?= $(shell nix-shell --run "py2hwsw $(CORE) print_core_name --py_params '$(PY_PARAMS)'")
VERSION ?= $(shell nix-shell --run "py2hwsw $(CORE) print_core_version --py_params '$(PY_PARAMS)'")
CORE_NAME=$(shell nix-shell --run "py2hwsw $(CORE) print_core_name --py_params '$(PY_PARAMS)'")

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

doc-view: doc-build
	nix-shell --run "make -C $(BUILD_DIR) doc-view DOC=$(DOC)"

.PHONY: all setup sim-build sim-run sim-waves sim-test fpga-build fpga-test doc-build doc-view

clean:
	nix-shell --run "py2hwsw $(CORE) clean --build_dir '$(BUILD_DIR)'"
	@rm -rf ../*.summary ../*.rpt fusesoc_exports *.core
	@find . -name \*~ -delete

.PHONY: clean

# 
# FuseSoC Targets
#

fusesoc-export: clean setup
	nix-shell --run "py2hwsw $(CORE) export_fusesoc --build_dir '$(BUILD_DIR)' --py_params '$(PY_PARAMS)'"

.PHONY: fusesoc-export

# Check if the target is `fusesoc-core-file` and define variables for it
ifneq ($(filter fusesoc-%,$(MAKECMDGOALS)),)

FS_REPO_NAME := $(subst _,-,$(CORE))-fs

# Get the latest commit hash from the remote repository
# NOTE: If you do not have write permissions to the IObundle repo, change the REPO_URL to your fork
REPO_URL := https://github.com/IObundle/$(FS_REPO_NAME)
$(info FuseSoC repo URL $(REPO_URL))

LATEST_FS_COMMIT = $(shell git ls-remote $(REPO_URL) HEAD | awk '{print $$1}')

# Using .tar.gz file from releases tab. Supported by fusesoc tool, but not yet supported by https://cores.fusesoc.net/
# define MULTILINE_TEXT
# provider:
#   name: url
#   url: https://github.com/IObundle/$(subst _,-,$(CORE))/releases/latest/download/$(CORE)_V$(VERSION).tar.gz
#   filetype: tar
# endef
# Alternative: Using sources from *-fs repo. Supported by fusesoc tool and https://cores.fusesoc.net/
define MULTILINE_TEXT
provider:
  name: github
  user: IObundle
  repo: $(FS_REPO_NAME)
  version: $(LATEST_FS_COMMIT)
endef
export MULTILINE_TEXT

endif

# NOTE: If you want to run this target from ghactions, you need to give it write permissions to the *-fs repo using a Personal Access Token (PAT).
# You need to generate a PAT to acces the *-fs repo:
#  - As org owner/admin of the *-fs repo, go to Settings > Developer settings > Fine-grained tokens > Generate new token.
#    - Select Repository access > Only select repositories (include both source and target repos).
#    - Grant Contents > Read & write (minimum for commits).
# Then you need add that PAT as a secret of this one (so that secrets.TARGET_REPO_PAT) becomes available.
#  - Add the PAT as a secret: Settings > Secrets and variables > Actions > New repository secret (name it e.g., TARGET_REPO_PAT).
# Finally, in the 'env' section of ci.yml, add: `PAT: ${{ secrets.TARGET_REPO_PAT }}`
#  - You can now use this url to have write permissions: `git clone https://x-access-token:${PAT}@github.com/your-org/target-repo.git`
#
# Automatically update *-fs repo with latest sources
fusesoc-update-fs-repo: fusesoc-export
	git clone $(REPO_URL) $(FS_REPO_NAME)
	# Delete all contents except .git directory
	#find $(FS_REPO_NAME) -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
	# Copy fusesoc_exports contents to FS_REPO_NAME root
	cp -r fusesoc_exports/* $(FS_REPO_NAME)/
	# Commit and push
	export CUR_COMMIT=$(shell git rev-parse HEAD);\
	cd $(FS_REPO_NAME) && \
	git config user.name "ghactions[bot]" && \
	git config user.email "ci@iobundle.com" && \
	git add . && \
	git commit --allow-empty -m "Auto-update from main repo ($$CUR_COMMIT)" && \
	git push origin main;
	@echo "FS repo updated successfully"

.PHONY: fusesoc-core-file

# Generate standalone FuseSoC .core file that references pre-built sources from a remote source using 'provider' section.
fusesoc-core-file: fusesoc-update-fs-repo # fusesoc-export
	cp fusesoc_exports/$(CORE_NAME).core .
	# Append provider remote url to .core file
	printf "\n%s\n" "$$MULTILINE_TEXT" >> $(CORE_NAME).core
	echo "Generated independent $(CORE_NAME).core file (with 'provider' section)."

.PHONY: fusesoc-core-file

fusesoc-sign: fusesoc-core-file
	mkdir -p fusesoc_sign/lib
	cp $(CORE_NAME).core fusesoc_sign/lib
	nix-shell --run "cd fusesoc_sign;\
	fusesoc library add lib;\
	fusesoc core sign $(CORE_NAME) ~/.ssh/iob-fusesoc-sign-key\
	"

.PHONY: fusesoc-sign

# Cores published must have a 'description' with less than 256 characters, otherwise it fails to publish to cores.fusesoc.net
fusesoc-publish: fusesoc-sign
	nix-shell --run "cd fusesoc_sign;\
	fusesoc core show $(CORE_NAME);\
	fusesoc-publish $(CORE_NAME) https://cores.fusesoc.net/\
	"

.PHONY: fusesoc-publish


# Release Artifacts

release-artifacts:
	make fusesoc-export BE_IF=AXI4
	tar -czf $(CORE)_axi_V$(VERSION).tar.gz -C ./fusesoc_exports .
	make fusesoc-export BE_IF=IOb
	tar -czf $(CORE)_iob_V$(VERSION).tar.gz -C ./fusesoc_exports .

.PHONY: release-artifacts
