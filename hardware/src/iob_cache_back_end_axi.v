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
      .axi_arvalid(axi_arvalid),
      .axi_araddr(axi_araddr),
      .axi_arlen(axi_arlen),
      .axi_arsize(axi_arsize),
      .axi_arburst(axi_arburst),
      .axi_arlock(axi_arlock),
      .axi_arcache(axi_arcache),
      .axi_arprot(axi_arprot),
      .axi_arqos(axi_arqos),
      .axi_arid(axi_arid),
      .axi_arready(axi_arready),

      // read data
      .axi_rvalid(axi_rvalid),
      .axi_rdata(axi_rdata),
      .axi_rresp(axi_rresp),
      .axi_rlast(axi_rlast),
      .axi_rready(axi_rready)
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
      .axi_awvalid(axi_awvalid),
      .axi_awaddr(axi_awaddr),
      .axi_awlen(axi_awlen),
      .axi_awsize(axi_awsize),
      .axi_awburst(axi_awburst),
      .axi_awlock(axi_awlock),
      .axi_awcache(axi_awcache),
      .axi_awprot(axi_awprot),
      .axi_awqos(axi_awqos),
      .axi_awid(axi_awid),
      .axi_awready(axi_awready),

      // write data
      .axi_wvalid(axi_wvalid),
      .axi_wdata(axi_wdata),
      .axi_wstrb(axi_wstrb),
      .axi_wready(axi_wready),
      .axi_wlast(axi_wlast),

      // write response
      .axi_bvalid(axi_bvalid),
      .axi_bresp(axi_bresp),
      .axi_bready(axi_bready)
      );

endmodule
