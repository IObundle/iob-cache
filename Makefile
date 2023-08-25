CORE := iob_cache
DISABLE_LINT:=1
include submodules/LIB/setup.mk

BE_IF ?= "AXI4"
SETUP_ARGS += BE_IF=$(BE_IF)
BE_DATA_W ?= "32"
SETUP_ARGS += BE_DATA_W=$(BE_DATA_W)

sim-build: clean
	rm -rf ../$(CORE)_V*
	make setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ sim-build

sim-run: clean
	rm -rf ../$(CORE)_V*
	make setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W)  && make -C ../$(CORE)_V*/ sim-run

sim-waves:
	make -C ../$(CORE)_V*/ sim-waves

sim-test: clean
	rm -rf ../$(CORE)_V*
	make setup BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W) && make -C ../$(CORE)_V*/ sim-test


