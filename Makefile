CACHE_DIR:=.
include ./core.mk

sim:
	make -C $(CACHE_SIM_DIR)

rp_sim:
	make -C $(CACHE_SIM_DIR)/rep_pol/

gtkwave:
	gtkwave $(CACHE_SIM_DIR)/iob_cache.vcd

gtkwave_rp:
	gtkwave $(CACHE_SIM_DIR)/rep_pol/rep_pol.vcd

synth:
	make -C $(CACHE_FPGA_DIR) synth

clean: 
	make -C $(CACHE_FPGA_DIR) clean
	make -C $(CACHE_SIM_DIR) clean
	make -C $(CACHE_SIM_DIR)/rep_pol/ clean

.PHONY: sim clean
