CACHE_DIR:=.
include ./config.mk

corename:
	@echo "CACHE"

#
# SIMULATE
#

sim:
	make -C $(SIM_DIR) run

sim-clean:
	make -C $(SIM_DIR) clean

#
# FPGA COMPILE
#

fpga-build:
	make -C $(FPGA_DIR) build

fpga-build-all:
	$(foreach s, $(FPGA_FAMILY_LIST), make fpga-build FPGA_FAMILY=$s;)

fpga-clean:
	make -C $(FPGA_DIR) clean

fpga-clean-all:
	$(foreach s, $(FPGA_FAMILY_LIST), make fpga-clean FPGA_FAMILY=$s;)


#
# DOCUMENT
#

doc-build: fpga-build-all
	make -C $(DOC_DIR) all

doc-build-all:
	$(foreach s, $(DOC_LIST), make doc-build DOC=$s;)


doc-clean:
	make -C $(DOC_DIR) clean

doc-clean-all:
	$(foreach s, $(DOC_LIST), make doc-clean DOC=$s;)


#
# CLEAN ALL
# 

clean-all: corename sim-clean fpga-clean-all doc-clean-all

