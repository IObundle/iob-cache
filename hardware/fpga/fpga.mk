include $(CACHE_DIR)/hardware/hardware.mk


clean: fpga-clean
	@rm -f *.hex *.bin

.PHONY: clean
