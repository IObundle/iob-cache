`timescale 1ns / 1ps

`include "iob_cache_conf.vh"

module iob_cache_backend_iob #(
   parameter ADDR_W     = `IOB_CACHE_ADDR_W,
   parameter DATA_W     = `IOB_CACHE_DATA_W,
   parameter BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
   parameter BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
   parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
   parameter WRITE_POL     = `IOB_CACHE_WRITE_THROUGH,
   parameter WTBUF_DEPTH_W = `IOB_CACHE_WTB_MEM_ADDR_W,

   //derived parameters
   parameter FE_NBYTES     = DATA_W / 8,
   parameter FE_NBYTES_W   = $clog2(FE_NBYTES),
   parameter BE_NBYTES     = BE_DATA_W / 8,
   parameter BE_NBYTES_W   = $clog2(BE_NBYTES),
   parameter LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / DATA_W)
) (
   // internal data interface
   output                                                               be_iob_avalid_o,
   output [ INT_ADDR_W-1:0]                                                      be_iob_addr_o,
   output [ INT_DATA_W-1:0]                                                      be_iob_wdata_o,
   output [(INT_DATA_W/8)-1:0]                                                   be_iob_wstrb_o,
   input                                                                be_iob_rvalid_i,
   input [ INT_DATA_W-1:0]                                                       be_iob_rdata_i,
   input                                                                be_iob_ready_i,


   // back-end memory interface
   output                                                             be_iob_avalid_o,
   output [ INT_ADDR_W-1:0]                                                      be_iob_addr_o,
   output [ INT_DATA_W-1:0]                                                      be_iob_wdata_o,
   output [(INT_DATA_W/8)-1:0]                                                   be_iob_wstrb_o,
   input                                                                be_iob_rvalid_i,
   input [ INT_DATA_W-1:0]                                                       be_iob_rdata_i,
   input                                                                be_iob_ready_i,
                                                                                
`include "iob_clkenrst_port.vs"
   );

   wire be_valid_read, be_valid_write;
   assign be_iob_avalid_o = be_valid_read | be_valid_write;

   wire [BE_ADDR_W-1:0] be_addr_read, be_addr_write;
   assign be_iob_addr_o  = (be_valid_read) ? be_addr_read : be_addr_write;

  
endmodule
