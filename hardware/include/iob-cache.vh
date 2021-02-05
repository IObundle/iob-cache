
//Address-port
`define WORD_ADDR // Word-addressable, (BE) addr becomes word-addressable (doesn't receive the byte-offset).

//Control-ports
`define CTRL_IO //ports that allow from outside signals to influence the invalidate and write-through buffer empty cache-control's functions.


//Replacement Policy
`define LRU       0 // Least Recently Used -- more resources intensive - N*log2(N) bits per cache line - Uses counters
`define PLRU_mru  1 // bit-based Pseudo-Least-Recently-Used, a simpler replacement policy than LRU, using a much lower complexity (lower resources) - N bits per cache line
`define PLRU_tree 2 // tree-based Pseudo-Least-Recently-Used, uses a tree that updates after any way received an hit, and points towards the oposing one. Uses less resources than bit-pseudo-lru - N-1 bits per cache line


//Write Policy
`define WRITE_THROUGH 0 //write-through not allocate: implements a write-through buffer
`define WRITE_BACK 1    //write-back allocate: implementes a dirty-memory

//Cache-Control
`define CTRL_ADDR_W 4
//Addresses for cache controller's task
`define ADDR_BUFFER_EMPTY     (`CTRL_ADDR_W'd1)
`define ADDR_BUFFER_FULL      (`CTRL_ADDR_W'd2) 
`define ADDR_CACHE_HIT        (`CTRL_ADDR_W'd3) 
`define ADDR_CACHE_MISS       (`CTRL_ADDR_W'd4) 
`define ADDR_CACHE_READ_HIT   (`CTRL_ADDR_W'd5) 
`define ADDR_CACHE_READ_MISS  (`CTRL_ADDR_W'd6) 
`define ADDR_CACHE_WRITE_HIT  (`CTRL_ADDR_W'd7) 
`define ADDR_CACHE_WRITE_MISS (`CTRL_ADDR_W'd8) 
`define ADDR_RESET_COUNTER    (`CTRL_ADDR_W'd9) 
`define ADDR_CACHE_INVALIDATE (`CTRL_ADDR_W'd10)
