SIM_DIR = simulation/icarus

sim:
	make -C $(SIM_DIR) 

gtkwave:
	gtkwave $(SIM_DIR)/iob_cache.vcd

clean: 
	make -C $(SIM_DIR) clean

.PHONY: sim clean
