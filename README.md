<!--
SPDX-FileCopyrightText: 2024 IObundle

SPDX-License-Identifier: MIT
-->

# IOb-cache

IOb-cache is a high-performance, configurable open-source Verilog cache. If you use or like this repository, please cite the respective article as indicated above in the "About" section.

IOb-cache supports pipeline architectures, allowing one request per clock cycle (read and write). 
IOb-cache has both Native (pipelined) and AXI4 back-end interfaces.
The Write Policy is configurable: either write-through/not-allocate or write-back/allocate.
The configuration supports the number of ways, address width, cache's word size (front-end data width), the memory's word size (back-end data width), the number of lines and words per line, replacement policy (if set associative), and cache-control module (allows performance measurement, cache invalidation, and write-through buffer status).

## Environment setup

This repository provides design files only. For running simulation and FPGA tests, IOb-Cache must be run inside [IOb-SoC](https://github.com/IObundle/iob-soc), where helpful information to set up your environment is provided.


After cloning IOb-SoC from its root directory, go to the IOb-Cache submodule:
```
cd submodules/CACHE
```

## Configuration

Edit the iob_cache.py file and update it according to your needs. The syntax of this file is ***almost*** self-explanatory; unfortunately, its documentation is under development.

Edit the Makefile file to set the back-end interface type (BE_IF) and width (BE_DATA_W) according to your needs at compile time. These variables can also be passed at the command line.
You can also change the SIMULATOR variable used to select a specific simulator or the DOC variable used to choose a document type to generate.

## Simulation
To simulate, run:
```
make sim-run [SIMULATOR=icarus!verilator|xcelium|vcs|questa] [BE_IF=AXI4|IOb] [BE_DATA_W=32|64|128|256|etc]
```

To build for simulation only, run:
```
make sim-build [SIMULATOR=icarus!verilator|xcelium|vcs|questa] [BE_IF=AXI4|IOb] [BE_DATA_W=32|64|128|256|etc] 
```
To execute a simple test suite by simulation, run 
``` 
make sim-test [SIMULATOR=icarus!verilator|xcelium|vcs|questa] [BE_IF=AXI4|IOb] [BE_DATA_W=32|64|128|256|etc]
```

## Documentation

Two document types are generated: the Product Brief, referred to as pb, and the User Guide, referred to as ug. 

To build a given document type DOC, run
```
make doc-build [DOC=pb|ug]
```


## Cleaning the build directory
To clean the build directory, run
```
make clean
```
