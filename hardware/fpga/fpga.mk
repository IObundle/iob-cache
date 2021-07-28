CACHE_DIR:=../../..
include $(CACHE_DIR)/hardware/hardware.mk

DEFINE+=$(defmacro)DATA_W=$(DATA_W)

FPGA_VSRC=$(addprefix ../, $(VSRC) )
FPGA_VHDR=$(addprefix ../, $(VHDR) )
FPGA_INCLUDE=$(addprefix ../, $(INCLUDE) )

$(FPGA_OBJ): $(CONSTRAINTS) $(VSRC) $(VHDR)
	mkdir -p $(FPGA_FAMILY)
	cd $(FPGA_FAMILY); ../build.sh "$(TOP_MODULE)" "$(FPGA_PART)" "$(FPGA_VSRC)" "$(FPGA_INCLUDE)" "$(DEFINE)"
