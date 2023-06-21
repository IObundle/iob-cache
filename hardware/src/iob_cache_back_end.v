`timescale 1ns / 1ps

`include "iob_cache_conf.vh"

module iob_cache_back_end #(
   parameter FE_ADDR_W     = `IOB_CACHE_FE_ADDR_W,
   parameter FE_DATA_W     = `IOB_CACHE_FE_DATA_W,
   parameter BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
   parameter BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
   parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
   parameter WRITE_POL     = `IOB_CACHE_WRITE_THROUGH,
   //derived parameters
   parameter FE_NBYTES     = FE_DATA_W / 8,
   parameter FE_NBYTES_W   = $clog2(FE_NBYTES),
   parameter BE_NBYTES     = BE_DATA_W / 8,
   parameter BE_NBYTES_W   = $clog2(BE_NBYTES),
   parameter LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W)
) (
   input clk_i,
   input arst_i,

   // write-through-buffer
   input                                                                         write_valid_i,
   input  [                 FE_ADDR_W-1 : FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr_i,
   input  [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 : 0] write_wdata_i,
   input  [                                                       FE_NBYTES-1:0] write_wstrb_i,
   output                                                                        write_ready_o,

   // cache-line replacement
   input                                        replace_valid_i,
   input  [FE_ADDR_W-1:BE_NBYTES_W + LINE2BE_W] replace_addr_i,
   output                                       replace_o,
   output                                       read_valid_o,
   output [                     LINE2BE_W -1:0] read_addr_o,
   output [                     BE_DATA_W -1:0] read_rdata_o,

   // back-end memory interface
   output                  be_valid_o,
   output [BE_ADDR_W -1:0] be_addr_o,
   output [ BE_DATA_W-1:0] be_wdata_o,
   output [ BE_NBYTES-1:0] be_wstrb_o,
   input  [ BE_DATA_W-1:0] be_rdata_i,
   input                   be_ready_i
);

   wire [BE_ADDR_W-1:0] be_addr_read, be_addr_write;
   wire be_valid_read, be_valid_write;

   assign be_addr_o  = (be_valid_read) ? be_addr_read : be_addr_write;
   assign be_valid_o = be_valid_read | be_valid_write;

   iob_cache_read_channel #(
      .FE_ADDR_W    (FE_ADDR_W),
      .FE_DATA_W    (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W)
   ) read_fsm (
      .clk_i        (clk_i),
      .arst_i        (arst_i),
      .replace_valid(replace_valid_i),
      .replace_addr (replace_addr_i),
      .replace      (replace_o),
      .read_valid   (read_valid_o),
      .read_addr    (read_addr_o),
      .read_rdata   (read_rdata_o),
      .be_addr      (be_addr_read),
      .be_valid     (be_valid_read),
      .be_ready     (be_ready_i),
      .be_rdata     (be_rdata_i)
   );

   iob_cache_write_channel #(
      .ADDR_W       (FE_ADDR_W),
      .DATA_W       (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WRITE_POL    (WRITE_POL),
      .WORD_OFFSET_W(WORD_OFFSET_W)
   ) write_fsm (
      .clk_i(clk_i),
      .arst_i(arst_i),

      .valid(write_valid_i),
      .addr (write_addr_i),
      .wstrb(write_wstrb_i),
      .wdata(write_wdata_i),
      .ready(write_ready_o),

      .be_valid(be_valid_write),
      .be_addr (be_addr_write),
      .be_wdata(be_wdata_o),
      .be_wstrb(be_wstrb_o),
      .be_ready(be_ready_i)
   );

endmodule
