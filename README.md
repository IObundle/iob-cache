<!--
SPDX-FileCopyrightText: 2024 IObundle

SPDX-License-Identifier: MIT
-->

# IOb-cache

IOb-cache is a high-performance, configurable open-source Verilog cache. If you use or like this repository, please cite the following article:
Roque, J.V.; Lopes, J.D.; Véstias, M.P.; de Sousa, J.T. IOb-Cache: A High-Performance Configurable Open-Source Cache. Algorithms 2021, 14, 218. https://doi.org/10.3390/a14080218 

IOb-cache supports pipeline architectures, allowing one request per clock cycle (read and write). 
IOb-cache has both Native (pipelined) and AXI4 back-end interfaces.
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



