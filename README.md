# iob-cache

IOb-cache is a configurable cpu cache developed by IOBundle. In its current state its possible to select its size (including the word-size), the type of Associativity (Direct-mapped or Associative), and the respective replacement policies. Currently it only allows the Write-throught policy. The memory requires AXI4-full interface.
 
## Organization of the repository

	/rtl/ - has all the verilog sources necessary for the synthesis of the cache. It has 2 folders:

		/src/ - Verilog sources:

			"gen_mem_reg.v" - a file with size-configurable storage sources:

				generable_memory : a logic memory

				generable_reg_file: an array of registers with asynchronous reset.

				They have the following configurable parameters:

					ADDR_W - Address width in bits (2^(ADDR_W) memory lines)

					DATA_W - Data width in bits (word-size) (default 32)

					MEM_W  - The size of each individual memory (in default its 8 (1 byte) to be byte-addressable)

					N_MEM  - The number of individual memories (in default its DATA_W/MEM_W, i.e. a 32-bit word memory with byte-addressable has 4 bytes).
						
			"iob-cache.v" - Has all the remaining files for the IOb-cache, its top-level modules and all the remaining modules (besides "iob-afifo.v"), as well some auxiliaries. This modules will be explained later.
		
		/header/ - the Verilog header file "iob-cache.vh" where the user can select some of the configurations that arent modular paramenters.
		
	/c-drive/ - the C programing Header  file, "iob-cache.h", that contains the multiple caches functions, all of them implemented logically, therefore only addresses.
							

## Cache Configurations

	Module Parameters (iob-cache.v): This are the parameters responsable for the caches size:

		ADDR_W - Address width, can be changed depending on the size of the memory connected to the cache (reducing this parameter will reduce the TAGs size, therefore reducint the TAG memory and its respective comparators)

		DATA_W - Data width, the word size (this value needs to allow byte-addressability (recommended 8, 16, 32, 64, 128, ..., although can be multiples of 8)

		N_BYTES - Number of Bytes allowed in the Word (DATA_W/8)

		NLINE_W - Number of cache lines width (number of total lines 2^(NLINE_W))

		OFFSET_W - Offset width, how many words of DATA_W size are in each cache line (each line has 2^(OFFSET_W) words)

		NWAY_W - Number of Ways width (the cache will have 2^(NWAY_W) ways when using its Associative configuration)

		WTBUF_DEPTH_W - The Width of the depht of the write-throught buffer

		I_NLINE_W and I_OFFSET_W: same as before but solely for the instruction cache when using the L1-ID configuration, which seperates both Data and Instruction cache, to avoid data-instruction conflicts. The Data cache will be configured using the other previous parameters (NLINE_W and OFFSET_W)
		
		Because of the nature of configurability of the cache, all this parameters have minimum value of 1 (not counting DATA_W and N_BYTES).


	Other configurations/defines (iob-cache.vh): This defines will configure the Associativity of the cache, its replacement policies as well some configurations regarding the available functions:

		ASSOC_CACHE - Associative cache, commenting this will turn it in to a Direct-Mapped cache

		L1_ID - Use this when its needed to divide in 2 memories, one for instructions and other for Data. This will increase the critical path (the access of each memory will be dependant of the "cache_ctrl_instr_access"). Each memory have its size individually configured

		Replacemente policies (only when ASSOC_CACHE is enabled):

			LRU - Least-Recently Used, most effective but uses the highest complexity O(N*logN) per cache line (N = number of ways)

			BIT_PLRU - Bit-based PseudoLRU, low complexity of O(N)) per cache line

			TREE_PLRU - Tree-based PseudoLRU, lowest complexity (of the currently implemented) of O(N-1) per cache line, but better eficiency than bit-plru.

		
		CTRL_CLK - to enable a 2*word size clock (a 32-bit cache will have a 64-bit clock) for performance measurement. Only to use when the system needs to measure the timing (number of clock cycles) performance but lacks any build logic for it, otherwise this can be disabled for resource saving.

		The remaining values are simply the one-hot encoding for the cache controllers counters (for performance measurement) as well its functions addresses.
		
		
## I/O ports

    clk - caches input clock signal. If the Memory connected to the cache uses a different clock, it requires a interconnect in between them for synchronization

    reset - resets the cache (places all the FSMs in a known state), also invalidates all the cache lines, resets the write-throught buffer (fifo) as well as the cache controllers counters

    cache_write_data - the input Data to be written (DATA_W sized)

    cache_wstrb - the input write strobe/enable of the input write data (byte-enabled) (NBYTES sized)

    cache_addr - the input signal for accessing a memory address (ADDR_W sized)

    cache_read_data - the output data of that accessing memory address

    cpu_req - (CPU request) the input signal the validates the access to the cache (Hand-shake input signal)

    cache_ack - (Cache acknowledge) the output signal representing the reply to the valid action  (Hand-shake returning signal, also known as ready signal).

    
    Cache controllers inputs:
    
        cache_ctrl_address - the input address for the respective cache function

        cache_ctrl_requested_data - the output of the returned value (based on the function)

        cache_ctrl_cpu_request - input signal that validates the access (Handshake)

        cache_ctrl_acknowledge - ouput signal that informs the data is ready (Handshake)

        cache_ctrl_instr_access - input signal that informs the controllers counters the type of access (instruction (1) or data (0)). Also used when using the configuration L1_ID (to select the memory).
    
    
    The remaining ports are the necessary AXI signals to connect to the memory.   


    

## Cache (Controller) Functions
                   
                   ctrl_cache_***_hit/miss: The number of cache hits or misses for each type of access (cache (total), instr (instruction), data, and then read or write)

                   ctrl_counter_reset: Resets all the previous counters

                   ctrl_cache_invalidate: invalidates the cache, by reseting the caches valid memory (array of flip-flops)

                   ctrl_clock_start: Starts the Clock counting (if iob-cache.vh CTR_CLK is enabled), also resets the counters (same as ctrl_counter_reset) for better measurement of performance. Increments each clock cycle

                   ctrl_clock_stop: Stops the counter.

                   ctrl_clock_upper: Received the upper value of the previous clock (in a 32-bit system its the upper 32 bits, the clock is twice the size of the word (since 32-bits clock would not be enough in most cases, also this clock can be disabled))

                   ctr_clock_lower: The lower value of the clock counter (the least significant 32 bits of a 32-bit system)

                   ctrl_buffer_empty: returns 1 if the buffer is empty (recommended for when a reset to the cache is needed, to avoid data-loss (data that still is in the buffer but wasnt written to the connected memory)

                   ctrl_buffer_full: returns 1 if the buffer is full.



## IOb-cache architecture

          - iob_cache: top-level module that connects the following multiple modules

          - cache_verification_controller: the caches main FSM, verifying when the cache is accessed, the type of access (for performance measurement), as initializing other processes (FSMs) if needed. This will be responsible for the Handshake. 

          - write_through_ctrl: The FSM responsible to write to the connected memory, using a buffer.
          
          - memory_cache: The module that contains all the caches memories, including the valid and TAG emmories. This module is also responsible to select the correct word (the way, and position in the line). Also contains the replacement_policy modules (LRU, and the PLRU policies). 

          - line_loader_ctrl: The FSM responsible to controlled the load od a cache line, when a read-miss occurs. Uses the AXIs burst protocols.

          - cache_controller: The Controller that has all the logic for the caches available functions.

          There is also a onehot-to-binary enconder module named ¨onehot_to_bin", necessary for when using the Associative configuration.