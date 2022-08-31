#iob-lib repo location
LIB_DIR=submodules/LIB

#iob-cache repo location as seen from iob-lib
CORE_DIR=../..

setup:
	make -C $(LIB_DIR) $@

clean:
	make -C $(LIB_DIR) $@

debug:
	make -C $(LIB_DIR) $@


.PHONY: setup clean debug
