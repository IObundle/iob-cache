// CORE VERSION
`include "iob_cache_version.vh"

//CORE DEFAULT PARAMETER CONFIGURATION

`define DATA_W 32
`define ADDR_W 24
`define BE_DATA_W 32
`define BE_ADDR_W 24
`define NWAYS_W 1
`define NLINES_W 7
`define WORD_OFFSET_W 3
`define WTBUF_DEPTH_W 4
`define REP_POLICY 0
`define WRITE_POL 0 
`define USE_CTRL 0
`define USE_CTRL_CNT 0

//Replacement Policy
// Least Recently Used -- more resources intensive - N*log2(N) bits per cache line - Uses counters
`define LRU 0
// bit-based Pseudo-Least-Recently-Used, a simpler replacement policy than LRU, using a much lower complexity (lower resources) - N bits per cache line
`define PLRU_MRU 1
// tree-based Pseudo-Least-Recently-Used, uses a tree that updates after any way received an hit, and points towards the oposing one. Uses less resources than bit-pseudo-lru - N-1 bits per cache line
`define PLRU_TREE 2

//Write Policy
//write-through not allocate: implements a write-through buffer  
`define WRITE_THROUGH 0
//write-back allocate: implementes a dirty-memory  
`define WRITE_BACK 1

//Cache controller address width
`define CTRL_ADDR_W 4

//AXI4
`define AXI_ID 0
`define AXI_ID_W 1

//DERIVED MACROS
`define NBYTES (DATA_W/8)
`define NBYTES_W ($clog2(`NBYTES))
`define BE_NBYTES (BE_DATA_W/8)
`define BE_NBYTES_W ($clog2(`BE_NBYTES))
`define LINE2BE_W (WORD_OFFSET_W-$clog2(BE_DATA_W/DATA_W))

//CACHE CONTROLLER ADDRESSES
`define ADDR_WTB_EMPTY    (`CTRL_ADDR_W'd1)
`define ADDR_WTB_FULL     (`CTRL_ADDR_W'd2) 
`define ADDR_RW_HIT       (`CTRL_ADDR_W'd3) 
`define ADDR_RW_MISS      (`CTRL_ADDR_W'd4) 
`define ADDR_READ_HIT     (`CTRL_ADDR_W'd5) 
`define ADDR_READ_MISS    (`CTRL_ADDR_W'd6) 
`define ADDR_WRITE_HIT    (`CTRL_ADDR_W'd7) 
`define ADDR_WRITE_MISS   (`CTRL_ADDR_W'd8) 
`define ADDR_RST_CNTRS    (`CTRL_ADDR_W'd9) 
`define ADDR_INVALIDATE   (`CTRL_ADDR_W'd10)
`define ADDR_VERSION      (`CTRL_ADDR_W'd11)
