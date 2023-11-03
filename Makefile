CORE := iob_cache
DISABLE_LINT:=1
LIB_DIR=../LIB
PROJECT_ROOT=..
export DISABLE_LINT
export LIB_DIR

all: sim-run

LIB_DIR=../LIB
PROJECT_ROOT=..
include ../LIB/setup.mk

BE_IF ?= "AXI4"
SETUP_ARGS += BE_IF=$(BE_IF)
BE_DATA_W ?= "32"
SETUP_ARGS += BE_DATA_W=$(BE_DATA_W)

DOC ?= ug
SETUP_ARGS += DOC=$(DOC)

clean:
	rm -rf ../$(CORE)_V*

setup:
	nix-shell --run "python3 -B ./$(CORE).py BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W)"

sim-build: clean setup
	nix-shell --run "make -C ../$(CORE)_V*/ sim-build"

sim-run: clean setup
	nix-shell --run "make -C ../$(CORE)_V*/ sim-run"

sim-waves:
	nix-shell --run "make -C ../$(CORE)_V*/ sim-waves"

sim-test: clean setup
	nix-shell --run "make -C ../$(CORE)_V*/ sim-test"

doc-build: clean setup
	nix-shell --run "make -C ../$(CORE)_V*/ doc-build DOC=$(DOC)"

doc-view: ../$(CORE)_V*/document/$(DOC).pdf
	nix-shell --run "make -C ../$(CORE)_V*/ doc-view DOC=$(DOC)"

../$(CORE)_V*/document/$(DOC).pdf: doc-build

