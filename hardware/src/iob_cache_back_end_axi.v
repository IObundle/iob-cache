`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "iob_cache.vh"

module iob_cache_back_end_axi
  #(
    parameter ADDR_W = `IOB_CACHE_ADDR_W,
    parameter DATA_W = `IOB_CACHE_DATA_W,
    parameter BE_ADDR_W = `IOB_CACHE_BE_ADDR_W,
    parameter BE_DATA_W = `IOB_CACHE_BE_DATA_W,
    parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
    parameter WRITE_POL = `IOB_CACHE_WRITE_THROUGH,
    parameter AXI_ID_W = `IOB_CACHE_AXI_ID_W,
    parameter AXI_LEN_W = `IOB_CACHE_AXI_LEN_W,
    parameter AXI_ADDR_W = BE_ADDR_W,
    parameter AXI_DATA_W = BE_DATA_W,
    parameter [AXI_ID_W-1:0] AXI_ID = `IOB_CACHE_AXI_ID
    )
   (
    // write-through-buffer
    input                                                           write_valid,
    input [ADDR_W-1 : `IOB_CACHE_NBYTES_W + WRITE_POL*WORD_OFFSET_W]          write_addr,
    input [DATA_W+WRITE_POL*(DATA_W*(2**WORD_OFFSET_W)-DATA_W)-1:0] write_wdata,
    input [`IOB_CACHE_NBYTES-1:0]                                   write_wstrb,
    output                                                          write_ready,

    // cache-line replacement
    input                                                           replace_valid,
    input [ADDR_W-1:`IOB_CACHE_BE_NBYTES_W + `IOB_CACHE_LINE2BE_W]                      replace_addr,
    output                                                          replace,
    output                                                          read_valid,
    output [`IOB_CACHE_LINE2BE_W -1:0]                                        read_addr,
    output [AXI_DATA_W -1:0]                                        read_rdata,
                                                                    
    // Back-end interface (AXI4 master)
`include "iob_cache_axi_m_port.vh"
`include "iob_clkrst_port.vh"
    );

   iob_cache_read_channel_axi
     #(
       .ADDR_W(ADDR_W),
       .DATA_W(DATA_W),
       .BE_ADDR_W (AXI_ADDR_W),
       .BE_DATA_W (AXI_DATA_W),
       .WORD_OFFSET_W(WORD_OFFSET_W),
       .AXI_ADDR_W(AXI_ADDR_W),
       .AXI_DATA_W(AXI_DATA_W),
       .AXI_ID_W(AXI_ID_W),
       .AXI_LEN_W(AXI_LEN_W),
       .AXI_ID  (AXI_ID)
       )
   read_fsm
     (
      .replace_valid (replace_valid),
      .replace_addr (replace_addr),
      .replace (replace),
      .read_valid (read_valid),
      .read_addr (read_addr),
      .read_rdata (read_rdata),
      `include "iob_cache_m_axi_read_portmap.vh"
      .clk(clk_i),
      .reset(rst_i)
      );

   iob_cache_write_channel_axi
     #(
       .ADDR_W(ADDR_W),
       .DATA_W(DATA_W),
       .BE_ADDR_W (AXI_ADDR_W),
       .BE_DATA_W (AXI_DATA_W),
       .WRITE_POL (WRITE_POL),
       .WORD_OFFSET_W(WORD_OFFSET_W),
       .AXI_ADDR_W(AXI_ADDR_W),
       .AXI_DATA_W(AXI_DATA_W),
       .AXI_ID_W(AXI_ID_W),
       .AXI_LEN_W(AXI_LEN_W),
       .AXI_ID  (AXI_ID)
       )
   write_fsm
     (
      .valid (write_valid),
      .addr (write_addr),
      .wstrb (write_wstrb),
      .wdata (write_wdata),
      .ready (write_ready),
      `include "iob_cache_m_axi_write_portmap.vh"
      .clk(clk_i),
      .reset(rst_i)
      );

endmodule
