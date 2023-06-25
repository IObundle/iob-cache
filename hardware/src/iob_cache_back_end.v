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
   input reset,

   // write-through-buffer
   input                                                                         write_valid,
   input  [                 FE_ADDR_W-1 : FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr,
   input  [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 : 0] write_wdata,
   input  [                                                       FE_NBYTES-1:0] write_wstrb,
   output                                                                        write_ack,

   // cache-line replacement
   input                                        replace_valid,
   input  [FE_ADDR_W-1:BE_NBYTES_W + LINE2BE_W] replace_addr,
   output                                       replace,
   output                                       read_valid,
   output [                     LINE2BE_W -1:0] read_addr,
   output [                     BE_DATA_W -1:0] read_rdata,

   // back-end memory interface
   output                  be_valid,
   output [BE_ADDR_W -1:0] be_addr,
   output [ BE_DATA_W-1:0] be_wdata,
   output [ BE_NBYTES-1:0] be_wstrb,
   input  [ BE_DATA_W-1:0] be_rdata,
   input                   be_rvalid,
   input                   be_ready
);

   wire [BE_ADDR_W-1:0] be_addr_read, be_addr_write;
   wire be_valid_read, be_valid_write;

   assign be_addr  = (be_valid_read) ? be_addr_read : be_addr_write;
   assign be_valid = be_valid_read | be_valid_write;

   iob_cache_read_channel #(
      .FE_ADDR_W    (FE_ADDR_W),
      .FE_DATA_W    (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W)
   ) read_fsm (
      .clk_i        (clk_i),
      .reset        (reset),
      .replace_valid(replace_valid),
      .replace_addr (replace_addr),
      .replace      (replace),
      .read_valid   (read_valid),
      .read_addr    (read_addr),
      .read_rdata   (read_rdata),
      .be_addr      (be_addr_read),
      .be_valid     (be_valid_read),
      .be_rvalid    (be_rvalid),
      .be_ready     (be_ready),
      .be_rdata     (be_rdata)
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
      .reset(reset),

      .valid(write_valid),
      .addr (write_addr),
      .wstrb(write_wstrb),
      .wdata(write_wdata),
      .wack(write_ack),

      .be_addr (be_addr_write),
      .be_valid(be_valid_write),
      .be_ready(be_ready),
      .be_wdata(be_wdata),
      .be_wstrb(be_wstrb)
   );

endmodule
