#iob-lib repo location
LIB_DIR=submodules/LIB

#iob-cache repo location as seen from iob-lib
CORE_DIR=../..

setup:
	cd $(LIB_DIR); ./iob-lib.sh $(CORE_DIR) $@

clean:
	cd $(LIB_DIR); ./iob-lib.sh $(CORE_DIR) $@

debug:
	cd $(LIB_DIR); ./iob-lib.sh $(CORE_DIR) $@


.PHONY: setup clean debug
