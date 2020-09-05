`timescale 1ns / 1ps
`include "iob-cache.vh"

module cache_memory
  #(
    //memory cache's parameters
    parameter FE_ADDR_W   = 32,       //Address width - width that will used for the cache 
    parameter FE_DATA_W   = 32,       //Data width - word size used for the cache
    parameter N_WAYS   = 1,        //Number of Cache Ways
    parameter LINE_OFF_W  = 6,      //Line-Offset Width - 2**NLINE_W total cache lines
    parameter WORD_OFF_W = 3,       //Word-Offset Width - 2**OFFSET_W total FE_DATA_W words per line 
    //Do NOT change - memory cache's parameters - dependency
    parameter NWAY_W   = $clog2(N_WAYS), //Cache Ways Width
    parameter FE_NBYTES  = FE_DATA_W/8,      //Number of Bytes per Word
    parameter BYTES_W = $clog2(FE_NBYTES), //Offset of the Number of Bytes per Word
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    //Do NOT change - slave parameters - dependency
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W), //burst offset based on the cache and memory word size
    //Replacement policy (N_WAYS > 1)
    parameter REP_POLICY = `LRU //LRU - Least Recently Used (stack/shift); LRU_add (1) - LRU with adders ; BIT_PLRU (2) - bit-based pseudoLRU; TREE_PLRU (3) - tree-based pseudoLRU
    )
   ( 
     input                                       clk,
     input                                       reset,
     //front-end
     input                                       valid,
     input [FE_ADDR_W-1:FE_BYTE_W]               addr,
     input [FE_DATA_W-1:0]                       wdata,
     input [FE_NBYTES-1:0]                       wstrb,
     output [FE_DATA_W-1:0]                      rdata,
     output                                      ready,
     //stored input value
     input                                       valid_reg,
     input [FE_ADDR_W-1:FE_BYTE_W]               addr_reg,
     input [FE_DATA_W-1:0]                       wdata_reg,
     input [FE_NBYTES-1:0]                       wstrb_reg,
     output [FE_DATA_W-1:0]                      rdata_reg,
     //back-end write-channel
     output                                      write_valid,
     output [FE_ADDR_W-1:FE_BYTE_W]              write_addr,
     output [FE_DATA_W-1:0]                      write_wdata,
     output [FE_NBYTES-1:0]                      write_wstrb,
     input                                       write_ready,
     //back-end read-channel
     output                                      replace_valid,
     output [FE_ADDR_W -1:BE_BYTES_W+LINE2MEM_W] replace_addr,
     input                                       replace_ready,
     input                                       read_valid,
     input [LINE2MEM_W-1:0]                      read_addr,
     input [BE_DATA_W-1:0]                       read_rdata,
     //cache-control
     input                                       invalidate,
     output [1:0]                                wtb_status,
     output                                      write_hit,
     output                                      write_miss,
     output                                      read_hit,
     output                                      read_miss
     );

   
   localparam TAG_W = FE_ADDR_W - (BYTES_W + WORD_OFF_W + LINE_OFF_W);
   
   wire [N_WAYS-1:0]                             way_hit, v, way_select;
   wire [TAG_W-1:0]                              tag = addr_reg[FE_ADDR_W-1 -:TAG_W];
   wire [LINE_OFF_W-1:0]                         index = addr_reg [FE_ADDR_W-TAG_W-1 -:LINE_OFF_W];
   wire [WORD_OFF_W-1:0]                         offset = addr_reg [FE_BYTE_W +: WORD_OFF_W];
   
   wire [N_WAYS*(2**WORD_OFF_W)*FE_DATA_W-1:0]   line_rdata;
   reg [N_WAYS*(2**WORD_OFF_W)*FE_NBYTES-1:0]    line_wstrb;


   wire                                          buffer_empty, buffer_full;   
   wire [FE_NBYTES+(FE_ADDR_W-BYTES_W)+(FE_DATA_W) -1 :0] buffer_dout;
   
   assign write_valid = ~buffer_empty;
   assign write_addr  = buffer_dout[FE_NBYTES + FE_DATA_W +: FE_ADDR_W - FE_BYTES_W];
   assign write_wdata = buffer_dout[FE_NBYTES             +: FE_DATA_W             ];
   assign write_wstrb = buffer_dout[0                     +: FE_NBYTES             ];

   iob_async_fifo #(
		    .DATA_WIDTH    (FE_ADDR_W-FE_BYTE_W + FE_DATA_W + FE_NBYTES),
		    .ADDRESS_WIDTH (WTBUF_DEPTH_W)
		    ) 
   write_throught_buffer 
     (
      .rst     (reset),       
      .data_out(buffer_dout), 
      .empty   (buffer_empty),
      .level_r (),
      .read_en (write_ready),
      .rclk    (clk),    
      .data_in ({addr_reg,wdata_reg,wstrb_reg}), 
      .full    (buffer_full),
      .level_w (),
      .write_en((|wstrb) & ready),
      .wclk    (clk)
      );

 
   assign replace_valid = (~hit & (valid_reg & ~|wstrb_ref)) & (buffer_empty & write_ready);
   assign replace_addr  = addr[FE_ADDR_W -1:BE_BYTES_W+LINE2MEM_W];


   assign ready = (hit & (valid_reg & ~|wstrb_reg) & replace_ready) | (~buffer_full & (valid & |wstrb));
   // read section needs to be the registered, so it doesn't change the moment ready asserts and updates the input. Write doesn't update on the same cycle as ready asserts, and in the next clock cycle, will have the next input.
   
endmodule
