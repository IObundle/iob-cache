# iob-cache

IOb-cache is a high-performance configurable open-source Verilog cache.

It supports pipeline architectures, allowing 1 request per clock cycle (read and write).

It has both Native (pipelined) and AXI4 back-end interfaces.

Write policy is write-through write-not-allocate.

Configuration supports the number of ways, address-width, cache's word-size (front-end data with), the memory's word-size (back-end data width), the number of lines and words per line, replacement policy (if set associative), and cache-control module (allows performance measurement, cache invalidation and write-through buffer status).

## Organization of the repository

/hardware/:

	./src/: cache's Verilog sources.
		
		iob_cache, iob_cache_axi: IOb-Cache's top-level module, back-end Native 
		and AXI4 interface respectively.
		
		front_end: Front-End, interface that connects the cache to a master. 
		Only this modules requires to be adapted when implmenting a cache in a 
		different system.
		
		cache_memory: cache's core module, contains all memories (including 
		write-through buffer) and the "main-controller" (datapath that asserts ready 
		when all conditions are met).
		
		back_end_native, back_end_axi: Back-End modules, contain both the controllers 
		write_channel and read_channel respective for the top-level selected.
		
		replacement_policy: replacement policy module, only implemented if cache is 
		set-associative. Currently has LRU, PLRU mru-based, and PLRU (binary) tree-based.
		
		cache_control: optional module used for performance measurement (if 
		counters are implemented), cache invalidation and buffer status.
		
	
	./header/: IOb-Cache's Verilog header source.
	
	./simulation/: simulation sources, available for the cache (both native and AXI) 
	and replacement policy module. Change the header files in this folder to change 
	the test's settings. Requires Icarus Verilog and GTKwave.
	
	./fpga/: synthesis sources, currently setup for Kintex KU040 Ultrascale FPGA
	
		synth.tcl: The module for the synthesis can be selected here.
		
		synth.xdc: The clock can be changed for different synthesis results (both 
		resources and timings).
		
/software/: Software C programing drivers.

/submodules/: Submodules required for both IOb-Cache (or its benchmarks) and other IObundle 
projects (IOb-SoC).


## Clone the repository

``git clone --recursive git@github.com:IObundle/iob-cache.git``

Access to Github by *ssh* is mandatory so that submodules can be updated.



## Simulation

The following commands will run the simulations. Requires Icarus Verilog and GTKWAVE.

To simulate IOb-Cache:
```
make sim
```
Follow by seeing the results using GTKWAVE

```
make gtkwave
```

To simulate Replacement Policy module:
```
make rp_sim
```
Follow by seeing the results using GTKWAVE

```
make gtkwave_rp
```

## Synthesis

The following commands will run synthesis, requires Vivado (with application open: "source /Vivado's path/setting64.sh").
Setting can be changed in /hardware/fpga/"board of choice (currently only 1 available)".
```
make synth
```

## Cleaning

The following command will clean all directories: 
```
make clean
```
