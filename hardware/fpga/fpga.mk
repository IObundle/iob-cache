include $(ROOT_DIR)/hardware/hardware.mk

#board specific top level source
VSRC+=$(ROOT_DIR)/hardware/src/iob-cache.v

clean: fpga-clean
	@rm -f *.hex *.bin

.PHONY: clean
