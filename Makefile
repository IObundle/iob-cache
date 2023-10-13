CORE := iob_cache
DISABLE_LINT:=1
export DISABLE_LINT
BE_IF ?= "AXI4"
SETUP_ARGS += BE_IF=$(BE_IF)
BE_DATA_W ?= "32"
SETUP_ARGS += BE_DATA_W=$(BE_DATA_W)

clean:
	rm -rf ../$(CORE)_V*

setup:
	python3 -B ./$(CORE).py BE_IF=$(BE_IF) BE_DATA_W=$(BE_DATA_W)

sim-build: clean setup
	make -C ../$(CORE)_V*/ sim-build

sim-run: clean setup
	make -C ../$(CORE)_V*/ sim-run

sim-waves:
	make -C ../$(CORE)_V*/ sim-waves

sim-test: clean setup
	make -C ../$(CORE)_V*/ sim-test


