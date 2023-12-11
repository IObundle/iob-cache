`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_iob #(
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
   parameter USE_CTRL      = `IOB_CACHE_USE_CTRL,
   parameter USE_CTRL_CNT  = `IOB_CACHE_USE_CTRL_CNT,
   //derived parameters
   parameter FE_NBYTES     = FE_DATA_W / 8,
   parameter FE_NBYTES_W   = $clog2(FE_NBYTES),
   parameter BE_NBYTES     = BE_DATA_W / 8,
   parameter BE_NBYTES_W   = $clog2(BE_NBYTES),
   parameter LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W),
   parameter ADDR_W        = USE_CTRL+FE_ADDR_W-FE_NBYTES_W,
   parameter DATA_W        = FE_DATA_W) (
   // Front-end interface (IOb native slave)
`include "iob_s_port.vs"

   // Back-end interface
   output [ 1-1:0]                            be_valid_o,
   output [ BE_ADDR_W-1:0]                    be_addr_o,
   output [ BE_DATA_W-1:0]                    be_wdata_o,
   output [ BE_NBYTES-1:0]                    be_wstrb_o,
   input [ BE_DATA_W-1:0]                     be_rdata_i,
   input                                      be_rvalid_i,
   input                                      be_ready_i,

   // Cache invalidate and write-trough buffer IO chain
   input [1-1:0]                              invalidate_i,
   output [1-1:0]                             invalidate_o,
   input [1-1:0]                              wtb_empty_i,
   output [1-1:0]                             wtb_empty_o,

   //General Interface Signals
   input [1-1:0]                              clk_i, //V2TEX_IO System clock input.
   input [1-1:0]                              cke_i, //V2TEX_IO System clock enable.
   input [1-1:0]                              arst_i //V2TEX_IO System reset, asynchronous and active high.
);

   //BLOCK Front-end & This NIP interface is connected to a processor or any other processing element that needs a cache buffer to improve the performance of accessing a slower but larger memory.
   wire data_req, data_ack;
   wire [FE_ADDR_W -1:FE_NBYTES_W] data_addr;
   wire [FE_DATA_W-1 : 0] data_wdata, data_rdata;
   wire [           FE_NBYTES-1:0] data_wstrb;
   wire [FE_ADDR_W -1:FE_NBYTES_W] data_addr_reg;
   wire [                 FE_DATA_W-1 : 0] data_wdata_reg;
   wire [           FE_NBYTES-1:0] data_wstrb_reg;
   wire                                    data_req_reg;
   

   wire                                    ctrl_req, ctrl_ack;
   wire [`IOB_CACHE_SWREG_ADDR_W-1:0]      ctrl_addr;
   wire [   USE_CTRL*(FE_DATA_W-1):0]      ctrl_rdata;
   wire                                    ctrl_invalidate;

   wire                                    wtbuf_full, wtbuf_empty;

   assign invalidate_o = ctrl_invalidate | invalidate_i;
   assign wtb_empty_o  = wtbuf_empty & wtb_empty_i;

   iob_cache_front_end #(
      .ADDR_W  (ADDR_W),
      .DATA_W  (DATA_W),
      .USE_CTRL(USE_CTRL)
   ) front_end (
      .clk_i(clk_i),
      .cke_i(cke_i),
      .arst_i(arst_i),

      // front-end port
`include "iob_s_s_portmap.vs"

      // cache-memory input signals
      .data_req_o (data_req),
      .data_addr_o(data_addr),

      // cache-memory output
      .data_rdata_i(data_rdata),
      .data_ack_i  (data_ack),

      // stored input signals
      .data_req_reg_o  (data_req_reg),
      .data_addr_reg_o (data_addr_reg),
      .data_wdata_reg_o(data_wdata_reg),
      .data_wstrb_reg_o(data_wstrb_reg),

      // cache-controller
      .ctrl_req_o  (ctrl_req),
      .ctrl_addr_o (ctrl_addr),
      .ctrl_rdata_i(ctrl_rdata),
      .ctrl_ack_i  (ctrl_ack)
   );

   //BLOCK Cache memory & This block contains the tag, data storage memories and the Write Through Buffer if the correspeonding write policy is selected; these memories are implemented either with RAM if large enough, or with registers if small enough.
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
      .USE_CTRL     (USE_CTRL),
      .USE_CTRL_CNT (USE_CTRL_CNT)
   ) cache_memory (
      .clk_i(clk_i),
      .cke_i(cke_i),
      .reset_i(arst_i),

      // front-end
      .req_i      (data_req),
      .addr_i     (data_addr[FE_ADDR_W-1 : BE_NBYTES_W+LINE2BE_W]),
      .rdata_o    (data_rdata),
      .ack_o      (data_ack),
      .req_reg_i  (data_req_reg),
      .addr_reg_i (data_addr_reg),
      .wdata_reg_i(data_wdata_reg),
      .wstrb_reg_i(data_wstrb_reg),

      // back-end
      // write-through-buffer (write-channel)
      .write_req_o  (write_req),
      .write_addr_o (write_addr),
      .write_wdata_o(write_wdata),
      .write_wstrb_o(write_wstrb),
      .write_ack_i  (write_ack),

      // cache-line replacement (read-channel)
      .replace_req_o (replace_req),
      .replace_addr_o(replace_addr),
      .replace_i     (replace),
      .read_req_i    (read_req),
      .read_addr_i   (read_addr),
      .read_rdata_i  (read_rdata),

      // control's signals
      .wtbuf_empty_o(wtbuf_empty),
      .wtbuf_full_o (wtbuf_full),
      .write_hit_o  (write_hit),
      .write_miss_o (write_miss),
      .read_hit_o   (read_hit),
      .read_miss_o  (read_miss),
      .invalidate_i (invalidate_o)
   );

   //BLOCK Back-end interface & Memory-side interface: if the cache is at the last level before the target memory module, the back-end interface connects to the target memory (e.g. DDR) controller; if the cache is not at the last level, the back-end interface connects to the next-level cache. This interface can be of type NPI or AXI4 as per configuration. If it is connected to the next-level IOb-Cache, the NPI type must be selected; if it is connected to a third party cache or memory controlller featuring an AXI4 interface, then the AXI4 type must be selected.
   iob_cache_back_end #(
      .FE_ADDR_W    (FE_ADDR_W),
      .FE_DATA_W    (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W),
      .WRITE_POL    (WRITE_POL)
   ) back_end (
      .clk_i(clk_i),
      .cke_i(cke_i),
      .arst_i(arst_i),

      // write-through-buffer (write-channel)
      .write_valid_i(write_req),
      .write_addr_i (write_addr),
      .write_wdata_i(write_wdata),
      .write_wstrb_i(write_wstrb),
      .write_ready_o(write_ack),

      // cache-line replacement (read-channel)
      .replace_valid_i(replace_req),
      .replace_addr_i (replace_addr),
      .replace_o      (replace),
      .read_valid_o   (read_req),
      .read_addr_o    (read_addr),
      .read_rdata_o   (read_rdata),

      // back-end native interface
      .be_valid_o(be_valid_o),
      .be_addr_o  (be_addr_o),
      .be_wdata_o (be_wdata_o),
      .be_wstrb_o (be_wstrb_o),
      .be_rdata_i (be_rdata_i),
      .be_rvalid_i(be_rvalid_i),
      .be_ready_i (be_ready_i)
   );

   //BLOCK Cache control & Cache controller: this block is used for invalidating the cache, monitoring the status of the Write Thorough buffer, and accessing read/write hit/miss counters.
   generate
      if (USE_CTRL) begin : g_ctrl
         iob_cache_control #(
            .DATA_W      (FE_DATA_W),
            .USE_CTRL_CNT(USE_CTRL_CNT)
         ) cache_control (
            .clk_i(clk_i),
            .reset_i(arst_i),

            // control's signals
            .valid_i(ctrl_req),
            .addr_i (ctrl_addr),

            // write data
            .wtbuf_full_i (wtbuf_full),
            .wtbuf_empty_i(wtbuf_empty),
            .write_hit_i  (write_hit),
            .write_miss_i (write_miss),
            .read_hit_i   (read_hit),
            .read_miss_i  (read_miss),

            .rdata_o     (ctrl_rdata),
            .ready_o     (ctrl_ack),
            .invalidate_o(ctrl_invalidate)
         );
      end
      else begin : g_no_ctrl
         assign ctrl_rdata      = 1'bx;
         assign ctrl_ack        = 1'bx;
         assign ctrl_invalidate = 1'b0;
      end
   endgenerate

endmodule
