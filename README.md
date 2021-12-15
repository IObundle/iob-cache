# IOb-cache

IOb-cache is a high-performance configurable open-source Verilog cache. If you use or like this repository, please cite the following article:

Roque, J.V.; Lopes, J.D.; Véstias, M.P.; de Sousa, J.T. IOb-Cache: A High-Performance Configurable Open-Source Cache. Algorithms 2021, 14, 218. https://doi.org/10.3390/a14080218 

IOb-cache supports pipeline architectures, allowing 1 request per clock cycle (read and write). 
IOb-cache has both Native (pipelined) and AXI4 back-end interfaces.
The write policy is configurable: either write-through/not-allocate or write-back/allocate.
Configuration supports the number of ways, address-width, cache's word-size (front-end data width), the memory's word-size (back-end data width), the number of lines and words per line, replacement policy (if set associative), and cache-control module (allows performance measurement, cache invalidation and write-through buffer status).

## Environment setup
IOb-SoC provides helpful information to set up your environment, please refer to [IOb-SoC](https://github.com/IObundle/iob-soc) in order to
* prepare your environment to connect to Github with ssh.
* install required tools and set your environment variables.

## Cloning the repository
```
git clone --recursive git@github.com:IObundle/iob-cache.git
```

## Configuration
Edit config.mk file and update its variables according to your needs. This file is located at the root repository. 

## Simulation
To simulate, run:
```
make sim SIMULATOR=<simulator directory name>  
```
SIMULATOR is a parameter used to select a specific simulator. Its value is the name of the simulator's run directory.
For example:
```
make sim SIMULATOR=icarus
```

To simulate with Icarus Verilog and to generate a VCD file for waveform visualization with the Gtkwave open-source program, run:
```
make sim SIMULATOR=icarus VCD=1 
```
To execute a simple test suite by simulation, run 
``` 
make sim-test SIMULATOR=<simulator directory name>
```
SIMULATOR parameter is used to select a given simulator, as explained above. 

To execute the test suite for all simulators listed in SIMULATOR\_LIST, run 
```
make test-sim
```
It is to note that SIMULATOR\_LIST is a variable set in config.mk file. 

To clean simulation generated files, run
```
make sim-clean SIMULATOR=<simulator directory name>
```
SIMULATOR parameter is used as explained above. 

To clean simulation generated files for all simulators, run
```
make sim-clean-all
```

## FPGA

To build for a target FPGA, run
```
make fpga-build FPGA_FAMILY=<board directory name>
```
FPGA_FAMILY is a parameter set to the name of the board's run directory.
For example:
```
make fpga-build FPGA_FAMILY=CYCLONEV-GT
```
To build for all target FPGAs listed in FPGA\_FAMILY\_LIST, run
```
make fpga-build-all
```
FPGA\_FAMILY\_LIST is a variable set in config.mk file

To build and execute a simple board test suite, run
```
make fpga-test FPGA_FAMILY=<board directory name>
```
FPGA_FAMILY parameter is set a explained above.


To clean the FPGA build generated files, run

```
make fpga-clean FPGA_FAMILY=<board directory name>
```
FPGA_FAMILY parameter is used as indicated above.

To clean the FPGA build generated files for all boards, run
```
make fpga-clean-all
```

## Documentation
Two document types are generated: the Product Brief refered to as pb and the User Guide refered to as ug. 

To build a given ducument type, run
```
make doc-build DOC=<document directory name>
```
DOC is a parameter whose value can be pb or ug.
For example:
```
make doc-build DOC=pb
```
To build all ducument types listed in DOC\_LIST, run
```
make doc-build-all
```
DOC\_LIST is a variable set in config.mk

To test the generated document, run
```
make doc-test DOC=<document directory name>
```
DOC is set as explained above.

To clean generated files for a specific document type, run
```
make doc-clean DOC=<document directory name>
```
DOC is set as explained above.

To clean generated files for all document types, run
```
make doc-clean-all
```

## Cleaning all directories
To clean all generated files, run
```
make clean-all
```
