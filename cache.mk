#RTL simulator
SIMULATOR:=icarus

#FPGA board
FPGA_BOARD:=AES-KU040-DB-G

#folder paths
CACHE_HW_DIR:=$(CACHE_DIR)/hardware
CACHE_SIM_DIR:=$(CACHE_HW_DIR)/simulation/$(SIMULATOR)
CACHE_FPGA_DIR:=$(CACHE_HW_DIR)/fpga/$(FPGA_BOARD)

#submodules
CACHE_MEM_DIR:=$(CACHE_DIR)/submodules/iob-mem
