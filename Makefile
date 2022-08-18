CORE_DIR=../..
LIB_DIR=submodules/LIB

export

setup:
	cd $(LIB_DIR); ./iob-lib.sh $(CORE_DIR) $@

clean:
	cd $(LIB_DIR); ./iob-lib.sh $(CORE_DIR) $@

debug:
	cd $(LIB_DIR); ./iob-lib.sh $(CORE_DIR) $@


.PHONY: setup clean debug
