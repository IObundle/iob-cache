# IOb-cache

IOb-cache is a high-performance configurable open-source Verilog cache. If you use or like this repository, please cite the following article:

Roque, J.V.; Lopes, J.D.; Véstias, M.P.; de Sousa, J.T. IOb-Cache: A High-Performance Configurable Open-Source Cache. Algorithms 2021, 14, 218. https://doi.org/10.3390/a14080218 

IOb-cache supports pipeline architectures, allowing 1 request per clock cycle (read and write). 
IOb-cache has both Native (pipelined) and AXI4 back-end interfaces.
The write policy is configurable: either write-through/not-allocate or write-back/allocate.
Configuration supports the number of ways, address-width, cache's word-size (front-end data width), the memory's word-size (back-end data width), the number of lines and words per line, replacement policy (if set associative), and cache-control module (allows performance measurement, cache invalidation and write-through buffer status).

## Environment setup
* Prepare your environment to connect to Github with ssh.
* Install required tools and set your environment variables.
* After cloning iob-cache repository as explained below, edit config.mk file and update its variables according to your needs.

## Cloning the repository
```
git clone --recursive git@github.com:IObundle/iob-cache.git
```

## Simulation
Simulation supports both Icarus Verilog and Verilator open-source simulators. 

To simulate, run:
```
make sim 
```
In this case Icarus Verilog is used by default.

To select a specific simulator, run:
```
make sim SIMULATOR=<simulator name>
```
\<simulator name\> can be icarus or verilator
For example:
```
make sim SIMULATOR=verilator
```
To simulate with Icarus Verilog and generate VCD file for waveform visualization with Gtkwave open-source program, run:
```
make sim VCD=1 
```
To execute a simple test suite by simulation, run 
``` 
make sim-test
```
Icarus Verilog is used by default. Otherwise, set SIMULATOR variable to select another simulator, as explained above. 

To execute the test suite for all simulators, run 
```
make test-sim
```
To clean simulation generated files, run
```
make sim-clean
```
Icarus Verilog is used by default. Another simulator can be selected by setting SIMULATOR variable, as explained above. 

To clean simulation generated files for all simulators, run
```
make sim-clean-all
```

## FPGA

To perform FPGA synthesis, run
```
make fpga-build
```
Both Quartus and Vivado are supported.

## Documentation

## Cleaning all directories
To clean all generated files, run
```
make clean-all
```

## Integration in IOb-SoC
Refer to [IOb-SoC](https://github.com/IObundle/iob-soc)
