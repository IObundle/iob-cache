#RTL simulator
CACHE_SIMULATOR:=icarus

#FPGA board
CACHE_FPGA_BOARD:=AES-KU040-DB-G

#folder paths
CACHE_HW_DIR:=$(CACHE_DIR)/hardware
CACHE_SIM_DIR:=$(CACHE_HW_DIR)/simulation/$(CACHE_SIMULATOR)
CACHE_FPGA_DIR:=$(CACHE_HW_DIR)/fpga/$(CACHE_FPGA_BOARD)

#submodules
CACHE_MEM_DIR:=$(CACHE_DIR)/submodules/iob-mem
INTERCON_DIR:=$(CACHE_DIR)/submodules/iob-interconnect
