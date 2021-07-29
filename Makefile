#
# TOP MAKEFILE
#
CACHE_DIR:=.
include core.mk

#
# SIMULATE
#

sim:
ifeq ($(SIM_SERVER),)
	make -C $(SIM_DIR) run SIMULATOR=$(SIMULATOR)
else
	ssh $(SIM_USER)@$(SIM_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	make -C $(SIM_DIR) clean
	rsync -avz --delete --exclude .git $(FPU_DIR) $(SIM_USER)@$(SIM_SERVER):$(USER)/$(REMOTE_ROOT_DIR)
	ssh $(SIM_USER)@$(SIM_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(SIM_DIR) run SIMULATOR=$(SIMULATOR)'
endif

sim-waves: $(SIM_DIR)/waves.gtkw $(SIM_DIR)/iob_cache.vcd
	gtkwave -a $^ &

$(SIM_DIR)/iob_cache.vcd:
	make sim

sim-clean:
	make -C $(SIM_DIR) clean
ifneq ($(SIM_SERVER),)
	rsync -avz --delete --exclude .git $(FPU_DIR) $(SIM_USER)@$(SIM_SERVER):$(USER)/$(REMOTE_ROOT_DIR)
	ssh $(SIM_USER)@$(SIM_SERVER) "if [ -d $(REMOTE_ROOT_DIR) ]; then cd $(REMOTE_ROOT_DIR); make -C $(SIM_DIR) clean; fi"
endif

#
# FPGA COMPILE
#

fpga:
ifeq ($(FPGA_SERVER),)
	make -C $(FPGA_DIR) run
else
	ssh $(FPGA_USER)@$(FPGA_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(CACHE_DIR) $(FPGA_USER)@$(FPGA_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(FPGA_USER)@$(FPGA_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(FPGA_DIR) run FPGA_FAMILY=$(FPGA_FAMILY)'
	mkdir -p $(FPGA_DIR)/$(FPGA_FAMILY)
	scp $(FPGA_USER)@$(FPGA_SERVER):$(REMOTE_ROOT_DIR)/$(FPGA_DIR)/$(FPGA_FAMILY)/$(FPGA_LOG) $(FPGA_DIR)/$(FPGA_FAMILY)
endif

fpga-clean:
	make -C $(FPGA_DIR) clean
ifneq ($(FPGA_SERVER),)
	rsync -avz --delete --exclude .git $(CACHE_DIR) $(FPGA_USER)@$(FPGA_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(FPGA_USER)@$(FPGA_SERVER) 'make -C $(REMOTE_ROOT_DIR)/$(FPGA_DIR) clean'
endif

#
# ASIC COMPILE
#

asic:
ifeq ($(shell hostname), $(ASIC_SERVER))
	make -C $(ASIC_DIR) ASIC=1
else
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(CACHE_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh -Y -C $(ASIC_USER)@$(ASIC_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(ASIC_DIR) ASIC=1'
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(ASIC_DIR)/synth/*.txt $(ASIC_DIR)/synth
endif

asic-synth:
ifeq ($(shell hostname), $(ASIC_SERVER))
	make -C $(ASIC_DIR) synth ASIC=1
else
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(CACHE_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh -Y -C $(ASIC_USER)@$(ASIC_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(ASIC_DIR) synth ASIC=1'
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(ASIC_DIR)/synth/*.txt $(ASIC_DIR)/synth
endif

asic-sim-synth:
ifeq ($(shell hostname), $(ASIC_SERVER))
	make -C $(HW_DIR)/simulation/ncsim run TEST_LOG=$(TEST_LOG) SYNTH=1
else
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(CACHE_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(ASIC_USER)@$(ASIC_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(HW_DIR)/simulation/ncsim run TEST_LOG=$(TEST_LOG) SYNTH=1'
ifeq ($(TEST_LOG),1)
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(HW_DIR)/simulation/ncsim/test.log $(HW_DIR)/simulation/ncsim
endif
endif

asic-clean:
	make -C $(ASIC_DIR) clean
ifneq ($(shell hostname), $(ASIC_SERVER))
	rsync -avz --delete --exclude .git $(CACHE_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ -d $(REMOTE_ROOT_DIR) ]; then cd $(REMOTE_ROOT_DIR); make -C $(ASIC_DIR) clean; fi"
endif

#
# DOCUMENT
#

doc: hardware/fpga/quartus/CYCLONEV-GT/quartus.log hardware/fpga/vivado/XCKU/vivado.log
	make -C document/$(DOC_TYPE) $(DOC_TYPE).pdf

hardware/fpga/quartus/CYCLONEV-GT/quartus.log:
	make fpga FPGA_FAMILY=CYCLONEV-GT

hardware/fpga/vivado/XCKU/vivado.log:
	make fpga FPGA_FAMILY=XCKU

doc-clean:
	make -C document/$(DOC_TYPE) clean

doc-clean-all:
	make -C document/pb clean
	make -C document/ug clean

doc-pdfclean:
	make -C document/$(DOC_TYPE) pdfclean

doc-pdfclean-all:
	make -C document/pb pdfclean
	make -C document/ug pdfclean

#
# CLEAN
#

clean: sim-clean fpga-clean doc-clean-all doc-pdfclean-all

.PHONY: sim sim-waves sim-clean \
	fpga fpga_clean \
	asic asic-synth asic-sim-synth asic-clean \
	doc doc-clean doc-clean-all doc-pdfclean doc-pdfclean-all \
	clean
