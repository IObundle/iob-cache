CORE_DIR=../..
LIB_DIR=submodules/LIB

export

setup:
	make -C $(LIB_DIR) $@

clean:
	make -C $(LIB_DIR) $@

debug:
	make -C $(LIB_DIR) $@


.PHONY: setup clean debug
