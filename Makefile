LIB_DIR=submodules/LIB

setup:
	make -C $(LIB_DIR) $@

clean:
	make -C $(LIB_DIR) $@

debug:
	make -C $(LIB_DIR) $@


.PHONY: setup clean debug
