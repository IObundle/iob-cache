/*
 IOb-Cache top-level module for AXI4 back-end interface
 
 this top module is necessary as Verilog does not allow generate statements on ports; it is not possible t have a single top-level module for iob-native interface and AXI4
 */

`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_axi #(
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
   parameter                USE_CTRL      = `IOB_CACHE_USE_CTRL,
   parameter                USE_CTRL_CNT  = `IOB_CACHE_USE_CTRL_CNT,
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
   parameter                LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W),
   parameter                ADDR_W        = USE_CTRL+FE_ADDR_W-FE_NBYTES_W,
   parameter                DATA_W        = FE_DATA_W
) (
`include "clk_en_rst_s_port.vs"
   // Front-end interface (IOb native slave)
`include "iob_s_port.vs"
   // Cache invalidate and write-trough buffer IO chain
   input [1-1:0]                                      invalidate_i,
   output [1-1:0]                                     invalidate_o,
   input [1-1:0]                                      wtb_empty_i,
   output [1-1:0]                                     wtb_empty_o,
   // AXI4 back-end interface
`include "axi_m_port.vs"
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
   wire [   USE_CTRL*(FE_DATA_W-1):0] ctrl_rdata;
   wire                               ctrl_invalidate;

   wire wtbuf_full, wtbuf_empty;

   assign invalidate_o = ctrl_invalidate | invalidate_i;
   assign wtb_empty_o  = wtbuf_empty & wtb_empty_i;

   iob_cache_front_end #(
      .ADDR_W  (FE_ADDR_W - FE_NBYTES_W),
      .DATA_W  (FE_DATA_W),
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
      .FE_ADDR_W    (FE_ADDR_W),
      .FE_DATA_W    (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
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

   //Back-end interface & This block interfaces with the system level or next-level cache.
   iob_cache_back_end_axi #(
      .FE_ADDR_W    (FE_ADDR_W),
      .FE_DATA_W    (FE_DATA_W),
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

      //back-end AXI4 interface
      `include "axi_m_m_portmap.vs"
      .clk_i(clk_i),
      .rst_i(arst_i)
   );

   //Cache control & Cache control block.
   generate
      if (USE_CTRL)
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
      else begin : g_no_cache_ctrl
         assign ctrl_rdata      = 1'bx;
         assign ctrl_ack        = 1'bx;
         assign ctrl_invalidate = 1'b0;
      end
   endgenerate

endmodule
