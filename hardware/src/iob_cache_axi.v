/*
 IOb-Cache top-level module for AXI4 back-end interface
 
 this top module is necessary as Verilog does not allow generate statements on ports; it is not possible t have a single top-level module for iob-native interface and AXI4
 */

`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_axi #(
   parameter                ADDR_W        = `IOB_CACHE_ADDR_W,
   parameter                DATA_W        = `IOB_CACHE_DATA_W,
   parameter                FE_ADDR_W     = `IOB_CACHE_FE_ADDR_W,
   parameter                FE_DATA_W     = `IOB_CACHE_FE_DATA_W,
   parameter                BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
   parameter                BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
   parameter                NWAYS_W       = `IOB_CACHE_NWAYS_W,
   parameter                NLINES_W      = `IOB_CACHE_NLINES_W,
   parameter                WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
   parameter                WTBUF_DEPTH_W = `IOB_CACHE_WTBUF_DEPTH_W,
   parameter                REP_POLICY    = `IOB_CACHE_PLRU_MRU,
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
   // Front-end interface (IOb native slave)
   input [ 1-1:0]                  req,
   input [FE_ADDR_W-1:FE_NBYTES_W] addr,
   input [ FE_DATA_W-1:0]          wdata,
   input [ FE_NBYTES-1:0]          wstrb,
   output [ FE_DATA_W-1:0]         rdata,
   output [ 1-1:0]                 ack,

   // Cache invalidate and write-trough buffer IO chain
   input [1-1:0]                   invalidate_in,
   output [1-1:0]                  invalidate_out,
   input [1-1:0]                   wtb_empty_in,
   output [1-1:0]                  wtb_empty_out,

   // AXI4 back-end interface
   `include "iob_axi_m_port.vs"
   //General Interface Signals
   input [1-1:0]                   clk_i, //System clock input
   input [1-1:0]                   rst_i   //System reset, asynchronous and active high
);

   //Front-end & Front-end interface.
   wire data_req, data_ack;
   wire [FE_ADDR_W -1 : FE_NBYTES_W] data_addr;
   wire [FE_DATA_W-1 : 0] data_wdata, data_rdata;
   wire [             FE_NBYTES-1:0] data_wstrb;
   wire [FE_ADDR_W -1 : FE_NBYTES_W] data_addr_reg;
   wire [           FE_DATA_W-1 : 0] data_wdata_reg;
   wire [             FE_NBYTES-1:0] data_wstrb_reg;
   wire                              data_req_reg;

   wire ctrl_req, ctrl_ack;
   wire [`IOB_CACHE_SWREG_ADDR_W-1:0] ctrl_addr;
   wire [FE_DATA_W-1:0] ctrl_rdata;
   wire                               ctrl_invalidate;

   wire wtbuf_full, wtbuf_empty;

   assign invalidate_out = ctrl_invalidate | invalidate_in;
   assign wtb_empty_out  = wtbuf_empty & wtb_empty_in;

   iob_cache_front_end #(
      .ADDR_W  (FE_ADDR_W - FE_NBYTES_W),
      .DATA_W  (FE_DATA_W),
   ) front_end (
      .clk_i(clk_i),
      .reset(rst_i),

      // front-end port
      .req  (req),
      .addr (addr),
      .wdata(wdata),
      .wstrb(wstrb),
      .rdata(rdata),
      .ack  (ack),

      // cache-memory input signals
      .data_req (data_req),
      .data_addr(data_addr),

      // cache-memory output
      .data_rdata(data_rdata),
      .data_ack  (data_ack),

      // stored input signals
      .data_req_reg  (data_req_reg),
      .data_addr_reg (data_addr_reg),
      .data_wdata_reg(data_wdata_reg),
      .data_wstrb_reg(data_wstrb_reg),

      // cache-controller
      .ctrl_req  (ctrl_req),
      .ctrl_addr (ctrl_addr),
      .ctrl_rdata(ctrl_rdata),
      .ctrl_ack  (ctrl_ack)
   );

   //Cache memory & This block implements the cache memory.
   wire write_hit, write_miss, read_hit, read_miss;

   // back-end write-channel
   wire write_req, write_ack;
   wire [                 FE_ADDR_W-1 : FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr;
   wire [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 : 0] write_wdata;
   wire [                                                       FE_NBYTES-1:0] write_wstrb;

   // back-end read-channel
   wire replace_req, replace;
   wire [FE_ADDR_W -1 : BE_NBYTES_W+LINE2BE_W] replace_addr;
   wire                                        read_req;
   wire [                       LINE2BE_W-1:0] read_addr;
   wire [                       BE_DATA_W-1:0] read_rdata;

   iob_cache_memory #(
      .ADDR_W       (FE_ADDR_W),
      .DATA_W       (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .NWAYS_W      (NWAYS_W),
      .NLINES_W     (NLINES_W),
      .WORD_OFFSET_W(WORD_OFFSET_W),
      .WTBUF_DEPTH_W(WTBUF_DEPTH_W),
      .REP_POLICY   (REP_POLICY),
      .WRITE_POL    (WRITE_POL)
   ) cache_memory (
      .clk_i(clk_i),
      .reset(rst_i),

      // front-end
      .req      (data_req),
      .addr     (data_addr[FE_ADDR_W-1 : BE_NBYTES_W+LINE2BE_W]),
      .rdata    (data_rdata),
      .ack      (data_ack),
      .req_reg  (data_req_reg),
      .addr_reg (data_addr_reg),
      .wdata_reg(data_wdata_reg),
      .wstrb_reg(data_wstrb_reg),

      // back-end
      // write-through-buffer (write-channel)
      .write_req  (write_req),
      .write_addr (write_addr),
      .write_wdata(write_wdata),
      .write_wstrb(write_wstrb),
      .write_ack  (write_ack),

      // cache-line replacement (read-channel)
      .replace_req (replace_req),
      .replace_addr(replace_addr),
      .replace     (replace),
      .read_req    (read_req),
      .read_addr   (read_addr),
      .read_rdata  (read_rdata),

      // control's signals
      .wtbuf_empty(wtbuf_empty),
      .wtbuf_full (wtbuf_full),
      .write_hit  (write_hit),
      .write_miss (write_miss),
      .read_hit   (read_hit),
      .read_miss  (read_miss),
      .invalidate (invalidate_out)
   );

   //Back-end interface & This block interfaces with the system level or next-level cache.
   iob_cache_back_end_axi #(
      .ADDR_W       (FE_ADDR_W),
      .DATA_W       (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W),
      .WRITE_POL    (WRITE_POL),
      .AXI_ADDR_W   (AXI_ADDR_W),
      .AXI_DATA_W   (AXI_DATA_W),
      .AXI_ID_W     (AXI_ID_W),
      .AXI_LEN_W    (AXI_LEN_W),
      .AXI_ID       (AXI_ID)
   ) back_end_axi (
      // write-through-buffer (write-channel)
      .write_valid(write_req),
      .write_addr (write_addr),
      .write_wdata(write_wdata),
      .write_wstrb(write_wstrb),
      .write_ready(write_ack),

      // cache-line replacement (read-channel)
      .replace_valid(replace_req),
      .replace_addr (replace_addr),
      .replace      (replace),
      .read_valid   (read_req),
      .read_addr    (read_addr),
      .read_rdata   (read_rdata),

      //back-end AXI4 interface
      `include "iob_axi_m_m_portmap.vs"
      .clk_i(clk_i),
      .rst_i(rst_i)
   );

   //Cache control & Cache control block.
         iob_cache_control #(
            .DATA_W      (DATA_W),
            .ADDR_W      (ADDR_W),
         ) cache_control (
            .clk_i(clk_i),
            .reset(rst_i),

            // control's signals
            .valid(ctrl_req),
            .addr (ctrl_addr),

            // write data
            .wtbuf_full (wtbuf_full),
            .wtbuf_empty(wtbuf_empty),
            .write_hit  (write_hit),
            .write_miss (write_miss),
            .read_hit   (read_hit),
            .read_miss  (read_miss),

            .rdata     (ctrl_rdata),
            .ready     (ctrl_ack),
            .invalidate(ctrl_invalidate)
         );

endmodule
