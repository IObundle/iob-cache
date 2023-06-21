`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_iob #(
    parameter ADDR_W        = `IOB_CACHE_ADDR_W,
    parameter DATA_W        = `IOB_CACHE_DATA_W,
    parameter FE_ADDR_W     = `IOB_CACHE_FE_ADDR_W,
    parameter FE_DATA_W     = `IOB_CACHE_FE_DATA_W,
    parameter BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
    parameter BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
    parameter NWAYS_W       = `IOB_CACHE_NWAYS_W,
    parameter NLINES_W      = `IOB_CACHE_NLINES_W,
    parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
    parameter WTBUF_DEPTH_W = `IOB_CACHE_WTBUF_DEPTH_W,
    parameter REP_POLICY    = `IOB_CACHE_REP_POLICY,
    parameter WRITE_POL     = `IOB_CACHE_WRITE_THROUGH,
    //derived parameters
    parameter NBYTES        = DATA_W / 8,
    parameter NBYTES_W      = $clog2(NBYTES),
    parameter FE_NBYTES     = FE_DATA_W / 8,
    parameter FE_NBYTES_W   = $clog2(FE_NBYTES),
    parameter BE_NBYTES     = BE_DATA_W / 8,
    parameter BE_NBYTES_W   = $clog2(BE_NBYTES),
    parameter LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W)
) (
    // Control interface
    input  [            1-1:0] ctrl_req_i,
    input  [ADDR_W-1:NBYTES_W] ctrl_addr_i,
    input  [       DATA_W-1:0] ctrl_wdata_i,
    input  [       NBYTES-1:0] ctrl_wstrb_i,
    output [       DATA_W-1:0] ctrl_rdata_o,
    output [            1-1:0] ctrl_ack_o,

    // Front-end interface (IOb native slave)
    input  [                  1-1:0] fe_req_i,
    input  [FE_ADDR_W-1:FE_NBYTES_W] fe_addr_i,
    input  [          FE_DATA_W-1:0] fe_wdata_i,
    input  [          FE_NBYTES-1:0] fe_wstrb_i,
    output [          FE_DATA_W-1:0] fe_rdata_o,
    output [                  1-1:0] fe_ack_o,

    // Back-end interface
    output [        1-1:0] be_req_o,
    output [BE_ADDR_W-1:0] be_addr_o,
    output [BE_DATA_W-1:0] be_wdata_o,
    output [BE_NBYTES-1:0] be_wstrb_o,
    input  [BE_DATA_W-1:0] be_rdata_i,
    input  [        1-1:0] be_ack_i,

    //General Interface Signals
    input [1-1:0] clk_i,  //V2TEX_IO System clock input.
    input [1-1:0] rst_i   //V2TEX_IO System reset, asynchronous and active high.
);


  wire data_req, data_ack;
  wire [FE_ADDR_W -1:FE_NBYTES_W] data_addr;
  wire [FE_DATA_W-1 : 0] data_wdata, data_rdata;
  wire [FE_NBYTES-1:0] data_wstrb;



  wire write_hit, write_miss, read_hit, read_miss;

  // back-end write-channel
  wire write_req, write_ack;
  wire [                   FE_ADDR_W-1:FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr;
  wire [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 : 0] write_wdata;
  wire [                                                       FE_NBYTES-1:0] write_wstrb;

  // back-end read-channel
  wire replace_req, replace;
  wire [FE_ADDR_W -1:BE_NBYTES_W+LINE2BE_W] replace_addr;
  wire                                      read_req;
  wire [                     LINE2BE_W-1:0] read_addr;
  wire [                     BE_DATA_W-1:0] read_rdata;

  // register inputs
  reg                                       data_req_reg;

  reg  [                     FE_ADDR_W-1:0] data_addr_reg;

  reg  [                     FE_DATA_W-1:0] data_wdata_reg;

  reg  [                     FE_NBYTES-1:0] data_wstrb_reg;

  always @(posedge clk_i, posedge reset) begin
    if (reset) begin
      data_req_reg   <= 0;
      data_addr_reg  <= 0;
      data_wdata_reg <= 0;
      data_wstrb_reg <= 0;
    end else begin
      data_req_reg   <= data_req_int;
      data_addr_reg  <= addr[ADDR_W-1:0];
      data_wdata_reg <= wdata;
      data_wstrb_reg <= wstrb;
    end
  end

  iob_cache_memory #(
      .FE_ADDR_W    (FE_ADDR_W),
      .FE_DATA_W    (FE_DATA_W),
      .BE_DATA_W    (BE_DATA_W),
      .NWAYS_W      (NWAYS_W),
      .NLINES_W     (NLINES_W),
      .WORD_OFFSET_W(WORD_OFFSET_W),
      .WTBUF_DEPTH_W(WTBUF_DEPTH_W),
      .REP_POLICY   (REP_POLICY),
      .WRITE_POL    (WRITE_POL),
  ) cache_memory (
      .clk_i         (clk_i),
      .reset         (rst_i),
      // front-end
      .req_i         (data_req),
      .addr_i        (data_addr[FE_ADDR_W-1 : BE_NBYTES_W+LINE2BE_W]),
      .rdata         (data_rdata),
      .ack           (data_ack),
      .req_reg       (data_req_reg),
      .addr_reg      (data_addr_reg),
      .wdata_reg     (data_wdata_reg),
      .wstrb_reg     (data_wstrb_reg),
      // back-end
      // write-through-buffer (write-channel)
      .write_req_i   (write_req),
      .write_addr_i  (write_addr),
      .write_wdata   (write_wdata),
      .write_wstrb   (write_wstrb),
      .write_ack     (write_ack),
      // cache-line replacement (read-channel)
      .replace_req_i (replace_req),
      .replace_addr_i(replace_addr),
      .replace       (replace),
      .read_req_i    (read_req),
      .read_addr_i   (read_addr),
      .read_rdata    (read_rdata),
      // control's signals
      .wtbuf_empty   (wtbuf_empty),
      .wtbuf_full    (wtbuf_full),
      .write_hit     (write_hit),
      .write_miss    (write_miss),
      .read_hit      (read_hit),
      .read_miss     (read_miss),
      .invalidate    (invalidate)
  );

  //Back-end interface
  iob_cache_back_end #(
      .FE_ADDR_W    (FE_ADDR_W),
      .FE_DATA_W    (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W),
      .WRITE_POL    (WRITE_POL)
  ) back_end (
      .clk_i         (clk_i),
      .reset         (rst_i),
      // write-through-buffer (write-channel)
      .write_valid   (write_req),
      .write_addr_i  (write_addr),
      .write_wdata   (write_wdata),
      .write_wstrb   (write_wstrb),
      .write_ready   (write_ack),
      // cache-line replacement (read-channel)
      .replace_valid (replace_req),
      .replace_addr_i(replace_addr),
      .replace       (replace),
      .read_valid    (read_req),
      .read_addr_i   (read_addr),
      .read_rdata    (read_rdata),
      // back-end native interface
      .be_valid      (be_req_o),
      .be_addr_o     (be_addr_o),
      .be_wdata      (be_wdata_o),
      .be_wstrb      (be_wstrb_o),
      .be_rdata      (be_rdata_i),
      .be_ready      (be_ack_i)
  );

  //Control block
  iob_cache_control #(
      .DATA_W(DATA_W),
      .ADDR_W(ADDR_W),
  ) cache_control (
      .clk_i (clk_i),
      .arst_i(rst_i),

      // control's signals
      .req_i  (ctrl_req),
      .addr_i (ctrl_addr),
      .rdata_o(ctrl_rdata),
      .ack_o  (ctrl_ack),

      // write data
      .write_hit (write_hit),
      .write_miss(write_miss),
      .read_hit  (read_hit),
      .read_miss (read_miss),
      .invalidate(invalidate)
  );

endmodule
