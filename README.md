<!--
SPDX-FileCopyrightText: 2024 IObundle

SPDX-License-Identifier: MIT
-->

# IOb-cache

IOb-cache is a high-performance, configurable open-source Verilog cache. If you use or like this repository, please cite the following article:
Roque, J.V.; Lopes, J.D.; Véstias, M.P.; de Sousa, J.T. IOb-Cache: A High-Performance Configurable Open-Source Cache. Algorithms 2021, 14, 218. https://doi.org/10.3390/a14080218 

IOb-cache supports pipeline architectures, allowing one request per clock cycle (read and write). 
IOb-cache has both Native `IOb` (pipelined) and `AXI4` back-end interfaces.
The Write Policy is configurable: either write-through/not-allocate or write-back/allocate.
The configuration supports the number of ways, address width, cache's word size (front-end data width), the memory's word size (back-end data width), the number of lines and words per line, replacement policy (if set associative), and cache-control module (allows performance measurement, cache invalidation, and write-through buffer status).


## Setup using Py2hwsw

IOb-Cache uses Py2hwsw to generate the hardware and software components. To
install Py2hwsw, follow the instructions in the [Py2hwsw
repository](https://github.com/IObundle/py2hwsw). The file iob_cache.py is
IOb-Cache's Py2hwsw description, which you can update to your needs.

Edit the Makefile file to set the back-end interface type (BE_IF) and width
(BE_DATA_W) according to your needs at compile time. These variables can also be
passed at the command line.  You can also change the SIMULATOR variable used to
select a specific simulator or the DOC variable used to choose a document type
to generate. The Makefile provides the following targets for simulation, FPGA
synthesis, and documentation generation.

## Quick setup

Py2HWSW runs on a Nix shell. First, download and install
[nix-shell](https://nixos.org/download.html#nix-install-linux).

To generate the Verilog sources, call the 'setup' Makefile target:
```
make setup
```
The sources are generated in the `../iob_cache_Vx.y/hardware/src/` directory, where Vx.y is the current version of IOb-cache.
The generated top level module is either `iob_cache_iob.v` or `iob_cache_axi.v`, depending on the value of the BE_IF Makefile variable.

To run in simulation, call the 'sim-run' Makefile target:
```
make sim-run
```

## Pre-built files

Two [FuseSoC](https://github.com/olofk/fusesoc)-compatible pre-built versions of iob-cache, with AXI4 and IOb back-end interfaces, are available in the [repository's release page](https://github.com/IObundle/iob-cache/releases).
The Cache's Verilog sources are available in the `iob_cache_*/hardware/src/` directory of the compressed tar.gz files in the release page.

To use these pre-built cores in FuseSoC, extract the compressed tar.gz files to a [FuseSoC library directory](https://fusesoc.readthedocs.io/en/stable/user/overview.html#discover-cores-the-package-manager).

