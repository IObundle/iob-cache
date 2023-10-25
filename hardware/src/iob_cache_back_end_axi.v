`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"
`include "iob_cache_conf.vh"

module iob_cache_back_end_axi #(
   parameter                FE_ADDR_W     = `IOB_CACHE_ADDR_W,
   parameter                FE_DATA_W     = `IOB_CACHE_DATA_W,
   parameter                BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
   parameter                BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
   parameter                WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
   parameter                WRITE_POL     = `IOB_CACHE_WRITE_THROUGH,
   parameter                AXI_ID_W      = `IOB_CACHE_AXI_ID_W,
   parameter [AXI_ID_W-1:0] AXI_ID        = `IOB_CACHE_AXI_ID,
   parameter                AXI_LEN_W     = `IOB_CACHE_AXI_LEN_W,
   parameter                AXI_ADDR_W    = BE_ADDR_W,
   parameter                AXI_DATA_W    = BE_DATA_W,
   //derived parameters
   parameter                FE_NBYTES     = FE_DATA_W / 8,
   parameter                FE_NBYTES_W   = $clog2(FE_NBYTES),
   parameter                BE_NBYTES     = BE_DATA_W / 8,
   parameter                BE_NBYTES_W   = $clog2(BE_NBYTES),
   parameter                LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W)
) (
   // write-through-buffer
   input                                                                     write_valid_i,
   input  [             FE_ADDR_W-1 : FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr_i,
   input  [FE_DATA_W+WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1:0] write_wdata_i,
   input  [                                                   FE_NBYTES-1:0] write_wstrb_i,
   output                                                                    write_ready_o,

   // cache-line replacement
   input                                     replace_valid_i,
   input  [FE_ADDR_W-1:BE_NBYTES_W + LINE2BE_W] replace_addr_i,
   output                                    replace_o,
   output                                    read_valid_o,
   output [                  LINE2BE_W -1:0] read_addr_o,
   output [                 AXI_DATA_W -1:0] read_rdata_o,

   // Back-end interface (AXI4 master)
   `include "axi_m_port.vs"
   input [1-1:0] clk_i,  //V2TEX_IO System clock input.
   input [1-1:0] rst_i   //V2TEX_IO System reset, asynchronous and active high.
);

   iob_cache_read_channel_axi #(
      .ADDR_W       (FE_ADDR_W),
      .DATA_W       (FE_DATA_W),
      .BE_ADDR_W    (AXI_ADDR_W),
      .BE_DATA_W    (AXI_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W),
      .AXI_ADDR_W   (AXI_ADDR_W),
      .AXI_DATA_W   (AXI_DATA_W),
      .AXI_ID_W     (AXI_ID_W),
      .AXI_LEN_W    (AXI_LEN_W),
      .AXI_ID       (AXI_ID)
   ) read_fsm (
      .replace_valid_i(replace_valid_i),
      .replace_addr_i (replace_addr_i),
      .replace_o      (replace_o),
      .read_valid_o   (read_valid_o),
      .read_addr_o    (read_addr_o),
      .read_rdata_o   (read_rdata_o),
      `include "axi_m_m_read_portmap.vs"
      .clk_i        (clk_i),
      .reset_i        (rst_i)
   );

   iob_cache_write_channel_axi #(
      .ADDR_W       (FE_ADDR_W),
      .DATA_W       (FE_DATA_W),
      .BE_ADDR_W    (AXI_ADDR_W),
      .BE_DATA_W    (AXI_DATA_W),
      .WRITE_POL    (WRITE_POL),
      .WORD_OFFSET_W(WORD_OFFSET_W),
      .AXI_ADDR_W   (AXI_ADDR_W),
      .AXI_DATA_W   (AXI_DATA_W),
      .AXI_ID_W     (AXI_ID_W),
      .AXI_LEN_W    (AXI_LEN_W),
      .AXI_ID       (AXI_ID)
   ) write_fsm (
      .valid_i(write_valid_i),
      .addr_i (write_addr_i),
      .wstrb_i(write_wstrb_i),
      .wdata_i(write_wdata_i),
      .ready_o(write_ready_o),
      `include "axi_m_m_write_portmap.vs"
      .clk_i(clk_i),
      .reset_i(rst_i)
   );

endmodule
