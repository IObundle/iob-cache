//Replacement Policy
`define LRU       0 // Least Recently Used -- more resources intensive - N*log2(N) bits per cache line - Uses counters
`define LRU_stack 1 // Least Recently Used -- Same as LRU but uses shifts to simulate a stack (Heap and Tail)
`define BIT_PLRU  2 // bit-based Pseudo-Least-Recently-Used, a simpler replacement policy than LRU, using a much lower complexity (lower resources) - N bits per cache line
`define TREE_PLRU 3 // tree-based Pseudo-Least-Recently-Used, uses a tree that updates after any way received an hit, and points towards the oposing one. Uses less resources than bit-pseudo-lru - N-1 bits per cache line

//CONTROLLER
`define CTRL_COUNTER_W 3
`define CTRL_ADDR_W 4

//uses one-hot enconding - counter for number of hit and misses
`define READ_HIT   (`CTRL_COUNTER_W'd1)
`define READ_MISS  (`CTRL_COUNTER_W'd2)
`define WRITE_HIT  (`CTRL_COUNTER_W'd3)
`define WRITE_MISS (`CTRL_COUNTER_W'd4)
`define INSTR_HIT  (`CTRL_COUNTER_W'd5)
`define INSTR_MISS (`CTRL_COUNTER_W'd6)

//Addresses for cache controller's task
`define ADDR_CACHE_INVALIDATE (`CTRL_ADDR_W'd1)
`define ADDR_BUFFER_EMPTY     (`CTRL_ADDR_W'd2)
`define ADDR_BUFFER_FULL      (`CTRL_ADDR_W'd3) 
`define ADDR_CACHE_HIT        (`CTRL_ADDR_W'd4) 
`define ADDR_CACHE_MISS       (`CTRL_ADDR_W'd5) 
`define ADDR_CACHE_READ_HIT   (`CTRL_ADDR_W'd6) 
`define ADDR_CACHE_READ_MISS  (`CTRL_ADDR_W'd7) 
`define ADDR_CACHE_WRITE_HIT  (`CTRL_ADDR_W'd8) 
`define ADDR_CACHE_WRITE_MISS (`CTRL_ADDR_W'd9) 
`define ADDR_RESET_COUNTER    (`CTRL_ADDR_W'd10) 
`define ADDR_INSTR_HIT        (`CTRL_ADDR_W'd11) 
`define ADDR_INSTR_MISS       (`CTRL_ADDR_W'd12) 
