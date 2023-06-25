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
   parameter LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W)
) (
   // Front-end interface (IOb native slave)
   input [ 1-1:0]                             valid,
   input [USE_CTRL+FE_ADDR_W-FE_NBYTES_W-1:0] addr,
   input [ FE_DATA_W-1:0]                     wdata,
   input [ FE_NBYTES-1:0]                     wstrb,
   output [ FE_DATA_W-1:0]                    rdata,
   output                                     rvalid,
   output                                     ready,

   // Back-end interface
   output [ 1-1:0]                            be_valid,
   output [ BE_ADDR_W-1:0]                    be_addr,
   output [ BE_DATA_W-1:0]                    be_wdata,
   output [ BE_NBYTES-1:0]                    be_wstrb,
   input [ BE_DATA_W-1:0]                     be_rdata,
   input [ 1-1:0]                             be_rvalid,
   input [ 1-1:0]                             be_ready,

   // Cache invalidate and write-trough buffer IO chain
   input [1-1:0]                              invalidate_in,
   output [1-1:0]                             invalidate_out,
   input [1-1:0]                              wtb_empty_in,
   output [1-1:0]                             wtb_empty_out,

   //General Interface Signals
   input [1-1:0]                              clk_i, //V2TEX_IO System clock input.
   input [1-1:0]                              rst_i   //V2TEX_IO System reset, asynchronous and active high.
);

   wire                                               ack;
   
   //BLOCK Front-end & This NIP interface is connected to a processor or any other processing element that needs a cache buffer to improve the performance of accessing a slower but larger memory.
   wire data_valid, data_ack;
   wire [FE_ADDR_W -1:FE_NBYTES_W] data_addr;
   wire [FE_DATA_W-1 : 0] data_wdata, data_rdata;
   wire [           FE_NBYTES-1:0] data_wstrb;
   wire [FE_ADDR_W -1:FE_NBYTES_W] data_addr_reg;
   wire [                 FE_DATA_W-1 : 0] data_wdata_reg;
   wire [           FE_NBYTES-1:0] data_wstrb_reg;
   wire                                    data_valid_reg;
   

   wire                                    ctrl_valid, ctrl_ack;
   wire [`IOB_CACHE_SWREG_ADDR_W-1:0]      ctrl_addr;
   wire [   USE_CTRL*(FE_DATA_W-1):0]      ctrl_rdata;
   wire                                    ctrl_invalidate;

   wire                                    wtbuf_full, wtbuf_empty;

   assign invalidate_out = ctrl_invalidate | invalidate_in;
   assign wtb_empty_out  = wtbuf_empty & wtb_empty_in;

   iob_cache_front_end #(
      .ADDR_W  (FE_ADDR_W - FE_NBYTES_W),
      .DATA_W  (FE_DATA_W),
      .USE_CTRL(USE_CTRL)
   ) front_end (
      .clk_i(clk_i),
      .reset(rst_i),

      // front-end port
      .valid  (valid),
      .addr (addr),
      .wdata(wdata),
      .wstrb(wstrb),
      .rdata(rdata),
      .rvalid(rvalid),
      .ready(ready),
      .ack  (ack),

      // cache-memory input signals
      .data_valid (data_valid),
      .data_addr(data_addr),

      // cache-memory output
      .data_rdata(data_rdata),
      .data_ack  (data_ack),

      // stored input signals
      .data_valid_reg  (data_valid_reg),
      .data_addr_reg (data_addr_reg),
      .data_wdata_reg(data_wdata_reg),
      .data_wstrb_reg(data_wstrb_reg),

      // cache-controller
      .ctrl_valid  (ctrl_valid),
      .ctrl_addr (ctrl_addr),
      .ctrl_rdata(ctrl_rdata),
      .ctrl_ack  (ctrl_ack)
   );

   //BLOCK Cache memory & This block contains the tag, data storage memories and the Write Through Buffer if the correspeonding write policy is selected; these memories are implemented either with RAM if large enough, or with registers if small enough.
   wire write_hit, write_miss, read_hit, read_miss;

   // back-end write-channel
   wire write_valid, write_ack;
   wire [                   FE_ADDR_W-1:FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr;
   wire [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 : 0] write_wdata;
   wire [                                                       FE_NBYTES-1:0] write_wstrb;

   // back-end read-channel
   wire replace_valid, replace;
   wire [FE_ADDR_W -1:BE_NBYTES_W+LINE2BE_W] replace_addr;
   wire                                      read_valid;
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
      .reset(rst_i),

      // front-end
      .valid      (data_valid),
      .addr     (data_addr[FE_ADDR_W-1 : BE_NBYTES_W+LINE2BE_W]),
      .rdata    (data_rdata),
      .ack      (data_ack),
      .valid_reg  (data_valid_reg),
      .addr_reg (data_addr_reg),
      .wdata_reg(data_wdata_reg),
      .wstrb_reg(data_wstrb_reg),

      // back-end
      // write-through-buffer (write-channel)
      .write_valid  (write_valid),
      .write_addr (write_addr),
      .write_wdata(write_wdata),
      .write_wstrb(write_wstrb),
      .write_ack  (write_ack),

      // cache-line replacement (read-channel)
      .replace_valid (replace_valid),
      .replace_addr(replace_addr),
      .replace     (replace),
      .read_valid    (read_valid),
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
      .reset(rst_i),

      // write-through-buffer (write-channel)
      .write_valid(write_valid),
      .write_addr (write_addr),
      .write_wdata(write_wdata),
      .write_wstrb(write_wstrb),
      .write_ack(write_ack),

      // cache-line replacement (read-channel)
      .replace_valid(replace_valid),
      .replace_addr (replace_addr),
      .replace      (replace),
      .read_valid   (read_valid),
      .read_addr    (read_addr),
      .read_rdata   (read_rdata),

      // back-end native interface
      .be_valid(be_valid),
      .be_addr (be_addr),
      .be_wdata(be_wdata),
      .be_wstrb(be_wstrb),
      .be_rdata(be_rdata),
      .be_ready(be_ready),
      .be_rvalid(be_rvalid)

   );

   //BLOCK Cache control & Cache controller: this block is used for invalidating the cache, monitoring the status of the Write Thorough buffer, and accessing read/write hit/miss counters.
   generate
      if (USE_CTRL)
         iob_cache_control #(
            .DATA_W      (FE_DATA_W),
            .USE_CTRL_CNT(USE_CTRL_CNT)
         ) cache_control (
            .clk_i(clk_i),
            .reset(rst_i),

            // control's signals
            .valid(ctrl_valid),
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
      else begin : g_no_ctrl
         assign ctrl_rdata      = 1'bx;
         assign ctrl_ack        = 1'bx;
         assign ctrl_invalidate = 1'b0;
      end
   endgenerate

endmodule
