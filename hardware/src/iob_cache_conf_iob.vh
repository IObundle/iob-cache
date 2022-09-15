// CORE VERSION
`include "iob_cache_version.vh"

//CORE MACRO CONFIGURATION
// no configuration

//CORE PARAMETER CONFIGURATION

`define IOB_CACHE_DATA_W 32
`define IOB_CACHE_ADDR_W 24
`define IOB_CACHE_BE_DATA_W 32
`define IOB_CACHE_BE_ADDR_W 24
`define IOB_CACHE_NWAYS_W 1
`define IOB_CACHE_NLINES_W 7
`define IOB_CACHE_WORD_OFFSET_W 3
`define IOB_CACHE_WTBUF_DEPTH_W 4
`define IOB_CACHE_REP_POLICY 0
`define IOB_CACHE_WRITE_POL 0 
`define IOB_CACHE_USE_CTRL 0
`define IOB_CACHE_USE_CTRL_CNT 0

//Replacement Policy
// Least Recently Used -- more resources intensive - N*log2(N) bits per cache line - Uses counters
`define IOB_CACHE_LRU 0
// bit-based Pseudo-Least-Recently-Used, a simpler replacement policy than LRU, using a much lower complexity (lower resources) - N bits per cache line
`define IOB_CACHE_PLRU_MRU 1
// tree-based Pseudo-Least-Recently-Used, uses a tree that updates after any way received an hit, and points towards the oposing one. Uses less resources than bit-pseudo-lru - N-1 bits per cache line
`define IOB_CACHE_PLRU_TREE 2

//Write Policy
//write-through not allocate: implements a write-through buffer  
`define IOB_CACHE_WRITE_THROUGH 0
//write-back allocate: implementes a dirty-memory  
`define IOB_CACHE_WRITE_BACK 1

//AXI4
`define IOB_CACHE_AXI_ID_W 1
`define IOB_CACHE_AXI_LEN_W 4
`define IOB_CACHE_AXI_ID 0
`define IOB_CACHE_AXI_ID_W 1
