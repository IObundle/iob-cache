CORE := iob_cache
DISABLE_LINT:=1

all: sim-run

LIB_DIR=../LIB
PROJECT_ROOT=..
include ../LIB/setup.mk

BE_IF ?= "AXI4"

SETUP_ARGS += BE_IF=$(BE_IF)

BE_DATA_W ?= "32"

SETUP_ARGS += BE_DATA_W=$(BE_DATA_W)


#------------------------------------------------------------
# SIMULATION
#------------------------------------------------------------

sim-build: clean
	nix-shell --run "make build-setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ sim-build"

sim-run: clean
	nix-shell --run "make build-setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W)  && make -C ../$(CORE)_V*/ sim-run"

sim-waves:
	nix-shell --run "make -C ../$(CORE)_V*/ sim-waves"

sim-test: clean
	nix-shell --run "make build-setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ sim-test"


