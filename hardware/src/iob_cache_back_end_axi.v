`timescale 1ns / 1ps

`include "iob_cache.vh"

module iob_cache_back_end_axi
  #(
    parameter ADDR_W = `ADDR_W,
    parameter DATA_W = `DATA_W,
    parameter BE_ADDR_W = `BE_ADDR_W,
    parameter BE_DATA_W = `BE_DATA_W,
    parameter WORD_OFFSET_W = `WORD_OFFSET_W,
    parameter WRITE_POL = `WRITE_THROUGH
    )
   (
    // write-through-buffer
    input                                                              write_valid,
    input [ADDR_W-1 : `NBYTES_W + WRITE_POL*WORD_OFFSET_W]             write_addr,
    input [DATA_W + WRITE_POL*(DATA_W*(2**WORD_OFFSET_W)-DATA_W)-1 :0] write_wdata,
    input [`NBYTES-1:0]                                                write_wstrb,
    output                                                             write_ready,

    // cache-line replacement
    input                                                              replace_valid,
    input [ADDR_W -1: `NBYTES_W + WORD_OFFSET_W]                       replace_addr,
    output                                                             replace,
    output                                                             read_valid,
    output [`LINE2BE_W -1:0]                                           read_addr,
    output [BE_DATA_W -1:0]                                            read_rdata,

    // Back-end interface (AXI4 master)
`include "iob_cache_axi_m_port.vh"
`include "iob_gen_if.vh"
    );

   iob_cache_read_channel_axi
     #(
       .ADDR_W(ADDR_W),
       .DATA_W(DATA_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W)
       )
   read_fsm
     (
      .clk(clk),
      .reset(rst),
      .replace_valid (replace_valid),
      .replace_addr (replace_addr),
      .replace (replace),
      .read_valid (read_valid),
      .read_addr (read_addr),
      .read_rdata (read_rdata),

      // read address
      .axi_arvalid(iob_cache_axi_arvalid),
      .axi_araddr(iob_cache_axi_araddr),
      .axi_arlen(iob_cache_axi_arlen),
      .axi_arsize(iob_cache_axi_arsize),
      .axi_arburst(iob_cache_axi_arburst),
      .axi_arlock(iob_cache_axi_arlock),
      .axi_arcache(iob_cache_axi_arcache),
      .axi_arprot(iob_cache_axi_arprot),
      .axi_arqos(iob_cache_axi_arqos),
      .axi_arid(iob_cache_axi_arid),
      .axi_arready(iob_cache_axi_arready),

      // read data
      .axi_rvalid(iob_cache_axi_rvalid),
      .axi_rdata(iob_cache_axi_rdata),
      .axi_rresp(iob_cache_axi_rresp),
      .axi_rlast(iob_cache_axi_rlast),
      .axi_rready(iob_cache_axi_rready)
      );

   iob_cache_write_channel_axi
     #(
       .ADDR_W(ADDR_W),
       .DATA_W(DATA_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WRITE_POL (WRITE_POL),
       .WORD_OFFSET_W(WORD_OFFSET_W)
       )
   write_fsm
     (
      .clk(clk),
      .reset(rst),
      .valid (write_valid),
      .addr (write_addr),
      .wstrb (write_wstrb),
      .wdata (write_wdata),
      .ready (write_ready),

      // write address
      .axi_awvalid(iob_cache_axi_awvalid),
      .axi_awaddr(iob_cache_axi_awaddr),
      .axi_awlen(iob_cache_axi_awlen),
      .axi_awsize(iob_cache_axi_awsize),
      .axi_awburst(iob_cache_axi_awburst),
      .axi_awlock(iob_cache_axi_awlock),
      .axi_awcache(iob_cache_axi_awcache),
      .axi_awprot(iob_cache_axi_awprot),
      .axi_awqos(iob_cache_axi_awqos),
      .axi_awid(iob_cache_axi_awid),
      .axi_awready(iob_cache_axi_awready),

      // write data
      .axi_wvalid(iob_cache_axi_wvalid),
      .axi_wdata(iob_cache_axi_wdata),
      .axi_wstrb(iob_cache_axi_wstrb),
      .axi_wready(iob_cache_axi_wready),
      .axi_wlast(iob_cache_axi_wlast),

      // write response
      .axi_bvalid(iob_cache_axi_bvalid),
      .axi_bresp(iob_cache_axi_bresp),
      .axi_bready(iob_cache_axi_bready)
      );

endmodule
