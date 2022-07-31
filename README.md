# IOb-cache

IOb-cache is a high-performance configurable open-source Verilog cache. If you use or like this repository, please cite the following article:

Roque, J.V.; Lopes, J.D.; Véstias, M.P.; de Sousa, J.T. IOb-Cache: [A High-Performance Configurable Open-Source Cache. Algorithms 2021, 14, 218.] (https://doi.org/10.3390/a14080218)

IOb-Cache is an open-source configurable pipelined memory cache. The
processor-side interface (front-end) uses IObundle's Native Pipelined Interface
(NPI). The memory-side interface (back-end) can also be configured to use NPI or
the widely used AXI4 interface. The address and data widths of the front-end and
back-end are configurable to support multiple user cores and memories. IOb-Cache
is a K-Way Set-Associative cache, where K can vary from 1 (directly mapped) to 8
or more ways, provided the operating frequency after synthesis is
acceptable. IOb-Cache supports the two most common write policies: Write-Through
Not-Allocate and Write-Back Allocate.

IOb-Cache was developed in the scope of João Roque's master's thesis in
Electrical and Computer Engineering at the Instituto Superior Técnico of the
University of Lisbon. The Verilog code works well in IObundle's [IOb-SoC]
(https://github.com/IObundle/iob-soc) system-on-chip both in simulation and
FPGA. To be used in an ASIC, it would need to be lint-cleaned and verified more
thoroughly by RTL simulation to achieve 100\% code coverage desirably.

## Environment setup and requirements

### Operating system

IOb-Cache has been tested on Ubuntu 20.04.4 LTS

### Scripting

* Install Python 3; tested with version 3.8.10

### Simulation

* Install a stable version of the [Icarus Verilog simulator] (http://iverilog.icarus.com); tested with version 10.3.
* Install a stable version of the [Verilator simulator] (https://www.veripool.org/verilator); tested with version 4.216.

### FPGA compilation

The design compiles for Intel and AMD FPGAs. To run it, please use the the [IOb-SoC] (https://github.com/IObundle/iob-soc) system.

* Install the [Vivado] (https://www.xilinx.com/support/download.html) FPGA development tools; tested with version v2020.2
* Install the [Quartus] (https://www.veripool.org/verilator) FPGA development tools; tested with version 20.1.0


### Documentation

The IOb-Cache documents can be generated using Latex; tested with TeX Live version 2019/Debian.


### Running the FPGA tools remotely

If your local machine does not have the FPGA tools installed, the Makefile will
automatically ``rsync`` the files to a remote machine, run the tools on the
remote machine, and copy the results back. For this purpose, set the following
enviromnet variables:

* Vivado 
```Bash
export VIVADO_SERVER=quartusserver.myorg.com
export VIVADO_USER=quartususer
export VIVADOPATH=/path/to/vivado
```

* Quartus
```Bash
export QUARTUS_SERVER=quartusserver.myorg.com
export QUARTUS_USER=quartususer
export QUARTUSPATH=/path/to/quartus
```

* LICENSE FILES

For the proprietary FPGA tools, make sure you have suitable licenses installed, and provide the license information as below:

```Bash
export LM_LICENSE_FILE=port@licenseserver.myorg.com;lic_or_dat_file
```

## Cloning the repository
```
git clone --recursive git@github.com:IObundle/iob-cache.git
```

## Create, remove and debug the build directory

To create a build directory, run:
```
make setup
```
This command will create a build directory with the name iob\_cache\_Vxx.yy, where Vxx.yy is the current version of the IP core. 

To remove the build directory, run:
```
make clean
```

To debug the build directory, by printing some Makefile variables, run:
```
make debug
```

Create the build directory and enter it:
```
cd iob\_cache\_Vxx.yy
```


## Simulation


To compile the Verilog files without running the simulation, run:
```
make sim-build SIMULATOR=[icarus|verilator]
```
The ``SIMULATOR`` variable may be assigned to ``icarus`` or ``verilator`` to select one of the two supported simulators. If omitted the
default simulator is Icarus Verilog.

To simulate using the IP core, run:
```
make sim-run SIMULATOR=[icarus|verilator] [VCD=1]
```
To generate a VCD file for waveform visualization with the Gtkwave open-source program, optionally add VCD=1 to the command as shown above.

To execute the simulation test, run 
``` 
make sim-test SIMULATOR=[icarus|verilator]
```

To debug the simulation environment, by printing some Makefile variables, run:
```
make sim-debug
```

To clean the simulation generated files, run
```
make sim-clean SIMULATOR=[icarus|verilator]
```

## FPGA

To build the design for a target FPGA, run
```
make fpga-build FPGA_FAMILY=[CYCLONEV-GT|XCKU]
```
The ``FPGA_FAMILY`` variable may be assigned to ``CYCLONEV-GT`` (Intel Cyclone V GT family) or ``XCKU`` (AMD Kintex Ultrascale family) to 
select one of the two supported FPGA families. If omitted the default FPGA family is ``CYCLONEV-GT`.

To execute the FPGA build test, run
```
make fpga-test FPGA_FAMILY=[CYCLONEV-GT|XCKU]
```

To debug the FPGA build environment, by printing some Makefile variables, run:
```
make fpga-debug
```

To clean the FPGA build generated files, run
```
make fpga-clean FPGA_FAMILY=[CYCLONEV-GT|XCKU]
```

## Documentation

To build a given document type, run
```
make doc-build DOC=[pb|ug]
```
The DOC variable may be assigned to ``pb`` (product brief)  or ``ug`` (user guide) to select one of the two supported document types. If omitted the
default document type is ``pb``.

To test the generated document, run
```
make doc-test DOC=[pb|ug]
```

To debug the document build environment, by printing some Makefile variables, run:
```
make doc-debug
```

To clean generated files for a specific document type, run
```
make doc-clean DOC=[pb|ug]
```

## Testing
To execute all tests, run:
```
make test
```

## Cleaning
To clean all generated files, run
```
make clean
```
