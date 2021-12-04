# IOb-cache

IOb-cache is a high-performance configurable open-source Verilog cache. 
IOb-cache supports pipeline architectures, allowing 1 request per clock cycle (read and write).
It has both Native (pipelined) and AXI4 back-end interfaces.
The write policy is configurable: either write-through/not-allocate or write-back/allocate. 
Configuration supports the number of ways, address-width, cache's word-size (front-end data width), the memory's word-size (back-end data width), the number of lines and words per line, replacement policy (if set associative), and cache-control module (allows performance measurement, cache invalidation and write-through buffer status).

## Clone the repository
```
git clone --recursive git@github.com:IObundle/iob-cache.git
```

## Simulation
Simulation supports both Icarus Verilog and Verilator simulators. 

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
To simulate with generating VCD file using Icarus Verilog, run:
```
make sim VCD=1 
```
This command also allows to open gtkwave waveform viewer.

To simulate with regression testing, run 
``` 
make sim-test
```
In this case Icarus Verilog is selected by default. 
If you are interested in selecting another simulator, set SIMULATOR parameter as explained previously. 

To simulate with regression testing for all simulators, run 
```
make test-sim
```
To clean simulation generated files, run
```
make sim-clean
```
In this case Icarus Verilog is selected by default. 
If you are interested in selecting another simulator, set SIMULATOR parameter as explained previously. 

To clean simulation generated files for all simulators, run
```
make sim-clean-all
```

## FPGA

## Documentation

## Cleaning all directories

## Integration in IOb-SoC
Refer to [IOb-SoC](https://github.com/IObundle/iob-soc)
