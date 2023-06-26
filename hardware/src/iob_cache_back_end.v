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
   // write channel
   input                                                                        write_req_i,
   input [ FE_ADDR_W-1 : FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W]                 write_addr_i,
   input [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 : 0] write_wdata_i,
   input [ FE_NBYTES-1:0]                                                       write_wstrb_i,
   output                                                                       write_ack_o,

   // read channel
   input                                                                        read_req_i,
   input [FE_ADDR_W-1:BE_NBYTES_W + LINE2BE_W]                                  read_addr_i,
   output                                                                       read_valid_o,
   output [ LINE2BE_W -1:0]                                                     read_addr_o
   // back-end memory interface
`include "be_iob_m_port.vs"
`include "iob_clkrst_port.vs"
   );

   wire [BE_ADDR_W-1:0] be_addr_read, be_addr_write;
   wire be_valid_read, be_valid_write;

   
   assign be_iob_addr_o  = (be_valid_read) ? be_addr_read : be_addr_write;
   assign be_iob_avalid_o = be_valid_read | be_valid_write;

   iob_cache_read_channel #(
      .FE_ADDR_W    (FE_ADDR_W),
      .FE_DATA_W    (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W)
   ) read_fsm (
      .clk_i       (clk_i),
      .arst_i      (arst_i),
               
      .read_valid_i(read_valid_i),
      .read_addr_i (read_addr_i),
      .read_valid_o(read_valid_o),
      .read_addr_o (read_addr_o),

      .be_addr_o   (be_addr_read),
      .be_valid_o  (be_valid_read),
      .be_rvalid_i (be_rvalid),
      .be_rdata_i  (be_rdata),
      .be_ready_i  (be_ready)
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

      .valid_i(write_req_i),
      .addr_i (write_addr_i),
      .wstrb_i(write_wstrb_i),
      .wdata_i(write_wdata_i),
      .wack_i(write_ack_o),

      .be_valid_o(be_valid_write),
      .be_addr_o (be_addr_write),
      .be_wdata_o(be_wdata_o),
      .be_wstrb_o(be_wstrb_o),
      .be_ready_i(be_ready_i)
   );

endmodule
