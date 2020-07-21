SIM_DIR = hardware/simulation/icarus
FPGA_DIR = hardware/fpga/AES-KU040-DB-G

sim:
	make -C $(SIM_DIR) 
rp_sim:
	make -C $(SIM_DIR)/rep_pol/

gtkwave:
	gtkwave $(SIM_DIR)/iob_cache.vcd

gtkwave_rp:
	gtkwave $(SIM_DIR)/rep_pol/rep_pol.vcd

synth:
	make -C $(FPGA_DIR) synth

clean: 
	make -C $(FPGA_DIR) clean
	make -C $(SIM_DIR) clean
	make -C $(SIM_DIR)/rep_pol/ clean

.PHONY: sim clean
