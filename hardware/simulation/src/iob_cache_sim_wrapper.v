`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "iob_cache.vh"
`include "iob_cache_conf.vh"

module iob_cache_sim_wrapper #(
`ifdef AXI
   parameter                AXI_ID_W      = `IOB_CACHE_AXI_ID_W,
   parameter                AXI_LEN_W     = `IOB_CACHE_AXI_LEN_W,
   parameter                AXI_ADDR_W    = BE_ADDR_W,
   parameter                AXI_DATA_W    = BE_DATA_W,
   parameter [AXI_ID_W-1:0] AXI_ID        = `IOB_CACHE_AXI_ID,
`endif
   parameter                ADDR_W        = `IOB_CACHE_FE_ADDR_W,
   parameter                DATA_W        = `IOB_CACHE_FE_DATA_W,
   parameter                BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
   parameter                BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
   parameter                NWAYS_W       = `IOB_CACHE_NWAYS_W,
   parameter                NLINES_W      = `IOB_CACHE_NLINES_W,
   parameter                WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
   parameter                WTBUF_DEPTH_W = `IOB_CACHE_WTBUF_DEPTH_W,
   parameter                REP_POLICY    = `IOB_CACHE_REP_POLICY,
   parameter                WRITE_POL     = `IOB_CACHE_WRITE_THROUGH,
   parameter                USE_CTRL      = `IOB_CACHE_USE_CTRL,
   parameter                USE_CTRL_CNT  = `IOB_CACHE_USE_CTRL_CNT
) (
   // Front-end interface (IOb native slave)
   input  [                                  1-1:0] req,
   input  [USE_CTRL+ADDR_W-`IOB_CACHE_NBYTES_W-1:0] addr,
   input  [                             DATA_W-1:0] wdata,
   input  [                  `IOB_CACHE_NBYTES-1:0] wstrb,
   output [                             DATA_W-1:0] rdata,
   output [                                  1-1:0] ack,

   // Cache invalidate and write-trough buffer IO chain
   input  [1-1:0] invalidate_in,
   output [1-1:0] invalidate_out,
   input  [1-1:0] wtb_empty_in,
   output [1-1:0] wtb_empty_out,

   //General Interface Signals
   input [1-1:0] clk_i,  //V2TEX_IO System clock input.
   input [1-1:0] rst_i   //V2TEX_IO System reset, active high.
);

`ifdef AXI
   `include "iob_cache_axi_wire.vh"
`else
   wire                              be_req;
   reg                               be_ack;
   wire [  `IOB_CACHE_BE_ADDR_W-1:0] be_addr;
   wire [  `IOB_CACHE_BE_DATA_W-1:0] be_wdata;
   wire [`IOB_CACHE_BE_DATA_W/8-1:0] be_wstrb;
   wire [  `IOB_CACHE_BE_DATA_W-1:0] be_rdata;
`endif

   iob_cache #(
      .FE_ADDR_W    (ADDR_W),
      .FE_DATA_W    (DATA_W),
      .BE_ADDR_W    (`IOB_CACHE_BE_ADDR_W),
      .BE_DATA_W    (`IOB_CACHE_BE_DATA_W),
      .NWAYS_W      (`IOB_CACHE_NWAYS_W),
      .NLINES_W     (`IOB_CACHE_NLINES_W),
      .WORD_OFFSET_W(`IOB_CACHE_WORD_OFFSET_W),
      .WTBUF_DEPTH_W(`IOB_CACHE_WTBUF_DEPTH_W),
      .WRITE_POL    (`IOB_CACHE_WRITE_POL),
      .REP_POLICY   (`IOB_CACHE_REP_POLICY),
      .USE_CTRL     (`IOB_CACHE_USE_CTRL)
   ) cache (
      //front-end
      .wdata(wdata),
      .addr (addr),
      .wstrb(wstrb),
      .rdata(rdata),
      .req  (req),
      .ack  (ack),

      //invalidate / wtb empty
      .invalidate_in (1'b0),
      .invalidate_out(),
      .wtb_empty_in  (1'b1),
      .wtb_empty_out (),

      //back-end
`ifdef AXI
      `include "iob_cache_axi_m_portmap.vh"
`else
      .be_addr (be_addr),
      .be_wdata(be_wdata),
      .be_wstrb(be_wstrb),
      .be_rdata(be_rdata),
      .be_req  (be_req),
      .be_ack  (be_ack),
`endif
      .clk_i   (clk_i),
      .rst_i   (rst_i)
   );

`ifdef AXI
   axi_ram #(
      .ID_WIDTH  (`IOB_CACHE_AXI_ID_W),
      .LEN_WIDTH (`IOB_CACHE_AXI_LEN_W),
      .DATA_WIDTH(`IOB_CACHE_BE_DATA_W),
      .ADDR_WIDTH(`IOB_CACHE_BE_ADDR_W)
   ) axi_ram (
      `include "iob_cache_ram_axi_portmap.vh"
      .clk(clk_i),
      .rst(rst_i)
   );
`else
   iob_ram_sp_be #(
      .DATA_W(`IOB_CACHE_BE_DATA_W),
      .ADDR_W(`IOB_CACHE_BE_ADDR_W)
   ) native_ram (
      .clk_i (clk_i),
      .en_i  (be_req),
      .we_i  (be_wstrb),
      .addr_i(be_addr),
      .d_o   (be_rdata),
      .d_i   (be_wdata)
   );

   always @(posedge clk_i, posedge rst_i)
      if (rst_i) be_ack <= 1'b0;
      else be_ack <= be_req;
`endif

endmodule
