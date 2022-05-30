//CONTROLLER
`define CTRL_COUNTER_W 3
`define CTRL_ADDR_W 5

//counter for number of hit and misses
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
`define ADDR_CLK_START        (`CTRL_ADDR_W'd11) 
`define ADDR_CLK_STOP         (`CTRL_ADDR_W'd12) 
`define ADDR_CLK_UPPER        (`CTRL_ADDR_W'd13) 
`define ADDR_CLK_LOWER        (`CTRL_ADDR_W'd14) 
`define ADDR_INSTR_HIT        (`CTRL_ADDR_W'd15) 
`define ADDR_INSTR_MISS       (`CTRL_ADDR_W'd16) 
