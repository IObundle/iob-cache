//CACHE TYPE
`define ASSOC_CACHE //Associative Cache (N Ways) - Comment it for Direct Access Cache
//`define LRU // Least Recently Used
//`define BIT_PLRU // bit-based Pseudo-Least-Recently-Used, a simpler replacement policy than LRU, using a much lower complexity (lower resources) with similar performance
`define TREE_PLRU // tree-based Pseudo-Least-Recently-Used, uses a tree that updates after any way received an hit, and points towards the oposing one. Uses less resources than bit-pseudo-lru

////This following Replacement Policies are only for testing the Associative Cache, without a complex replacement algorithm (check how the memories (Data, Valid, TAG) are working, for example
//`define TAG_BASED //NOT A REAL RP, for testing only - Uses the LSB of the TAG section of the input Address to choose the Way
//`define COUNTER //NOT A REAL RP, for testing only - A counter that increments every times the Processor accesses the cache, using it to select the Way

//CONTROLLER
`define CTRL_CLK // Adds 64-bit clock counter for timing performance measurement
`define CTRL_COUNTER_W 6
`define CTRL_ADDR_W 4

//uses one-hot enconding - counter for number of hit and misses
`define INSTR_HIT       (`CTRL_COUNTER_W'd1)
`define INSTR_MISS      (`CTRL_COUNTER_W'd2)
`define DATA_READ_HIT   (`CTRL_COUNTER_W'd4)
`define DATA_READ_MISS  (`CTRL_COUNTER_W'd8)
`define DATA_WRITE_HIT  (`CTRL_COUNTER_W'd16)
`define DATA_WRITE_MISS (`CTRL_COUNTER_W'd32)

//Addresses for cache controller's task
`define ADDR_CACHE_HIT        (`CTRL_ADDR_W'd0)  
`define ADDR_CACHE_MISS       (`CTRL_ADDR_W'd1) 
`define ADDR_INSTR_HIT        (`CTRL_ADDR_W'd2) 
`define ADDR_INSTR_MISS       (`CTRL_ADDR_W'd3) 
`define ADDR_DATA_HIT         (`CTRL_ADDR_W'd4) 
`define ADDR_DATA_MISS        (`CTRL_ADDR_W'd5) 
`define ADDR_DATA_READ_HIT    (`CTRL_ADDR_W'd6) 
`define ADDR_DATA_READ_MISS   (`CTRL_ADDR_W'd7) 
`define ADDR_DATA_WRITE_HIT   (`CTRL_ADDR_W'd8) 
`define ADDR_DATA_WRITE_MISS  (`CTRL_ADDR_W'd9) 
`define ADDR_RESET_COUNTER    (`CTRL_ADDR_W'd10) 
`define ADDR_CACHE_INVALIDATE (`CTRL_ADDR_W'd11) 
`define ADDR_CLK_START        (`CTRL_ADDR_W'd12) 
`define ADDR_CLK_STOP         (`CTRL_ADDR_W'd13) 
`define ADDR_CLK_UPPER        (`CTRL_ADDR_W'd14) 
`define ADDR_CLK_LOWER        (`CTRL_ADDR_W'd15) 
