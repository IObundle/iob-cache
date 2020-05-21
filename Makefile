SIM_DIR = simulation/icarus

sim:
	make -C $(SIM_DIR) 
rp_sim:
	make -C $(SIM_DIR)/rep_pol/

gtkwave:
	gtkwave $(SIM_DIR)/iob_cache.vcd

gtkwave_rp:
	gtkwave $(SIM_DIR)/rep_pol/rep_pol.vcd

clean: 
	make -C $(SIM_DIR) clean
	make -C $(SIM_DIR)/rep_pol/ clean

.PHONY: sim clean
