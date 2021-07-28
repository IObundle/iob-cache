FPGA_OBJ?=$(FPGA_FAMILY)/$(TOP_MODULE)_0.qxp
CONSTRAINTS:=$(wildcard *.sdc)

include ../fpga.mk

run: $(FPGA_OBJ)
	if [ -f $(FPGA_FAMILY)/output_files/*.fit.summary ]; \
	then mv $(FPGA_FAMILY)/output_files/*.fit.summary $(FPGA_FAMILY)/quartus.log; fi

clean: cache_clean_hw
	 rm -rf $(FPGA_FAMILY) *.v *.vh

.PHONY: clean
