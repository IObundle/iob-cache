`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_iob 
  #(
    // control interface parameters
    parameter ADDR_W        = `IOB_CACHE_ADDR_W,
    parameter DATA_W        = `IOB_CACHE_DATA_W,
    // data frontend parameters
    parameter FE_ADDR_W     = `IOB_CACHE_FE_ADDR_W,
    parameter FE_DATA_W     = `IOB_CACHE_FE_DATA_W,
    // data backend parameters
    parameter BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
    parameter BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
    //cache parameters
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
    `include "iob_s_port.vs"

    // Front-end interface (IOb native slave)
    `include "fe_iob_s_port.vs"


    // Back-end interface
    `include "be_iob_m_port.vs"


    // Clock and nterface
   `include "iob_clkrst_port.vs"
);


   wire data_req, data_ack;
   wire [FE_ADDR_W -1:FE_NBYTES_W] data_addr;
   wire [FE_DATA_W-1 : 0]          data_wdata, data_rdata;
   wire [FE_NBYTES-1:0]            data_wstrb;


   //events
   wire                write_hit, write_miss, read_hit, read_miss;

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


   wire                                     wtbuf_empty;
   wire wtbuf_full;
   wire invalidate;

   
   wire [DATA_W-1:0] read_hit_cnt;
   wire [DATA_W-1:0] read_miss_cnt;
   wire [DATA_W-1:0] write_hit_cnt;
   wire [DATA_W-1:0] write_miss_cnt;
   
`include "iob_cache_swreg_inst.vs"
   
  iob_cache_memory #(
      .FE_ADDR_W    (FE_ADDR_W),
      .FE_DATA_W    (FE_DATA_W),
      .BE_DATA_W    (BE_DATA_W),
      .NWAYS_W      (NWAYS_W),
      .NLINES_W     (NLINES_W),
      .WORD_OFFSET_W(WORD_OFFSET_W),
      .WTBUF_DEPTH_W(WTBUF_DEPTH_W),
      .REP_POLICY   (REP_POLICY),
      .WRITE_POL    (WRITE_POL)
  ) cache_memory (
      .clk_i(clk_i),
      .reset(arst_i),
      // front-end
      .req_i    (data_req),
      .addr_i   (data_addr[FE_ADDR_W-1 : BE_NBYTES_W+LINE2BE_W]),
      .rdata_o    (data_rdata),
      .ack_o      (data_ack),
      // back-end
      // write-through-buffer (write-channel)
      .write_req_o (write_req),
      .write_addr_o(write_addr),
      .write_wdata_o (write_wdata),
      .write_wstrb_o (write_wstrb),
      .write_ack_i   (write_ack),
      // cache-line replacement (read-channel)
      .replace_req_i (replace_req),
      .replace_addr_i(replace_addr),
      .replace_i       (replace),
      .read_req_i    (read_req),
      .read_addr_i   (read_addr),
      .read_rdata_i    (read_rdata),
      // control's signals
      .wtbuf_empty_o   (wtbuf_empty),
      .wtbuf_full_o    (wtbuf_full),
      .write_hit_o     (write_hit),
      .write_miss_o    (write_miss),
      .read_hit_o      (read_hit),
      .read_miss_o    (read_miss),
      .invalidate_i    (invalidate)
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
   `include "be_iob_m_portmap.vs"
   `include "iob_clkrst_portmap.vs"

  );

  //Control block
  iob_cache_control #(
      .DATA_W(DATA_W),
      .ADDR_W(ADDR_W)
  ) cache_control 
    (
     .clk_i  (clk_i),
     .arst_i(arst_i),
     
     // write data
     .write_hit_i (write_hit),
     .write_miss_i(write_miss),
     .read_hit_i  (read_hit),
     .read_miss_i (read_miss),
     .invalidate_i(invalidate),

     .read_hit_cnt_o (read_hit_cnt),
     .read_miss_cnt_o(read_miss_cnt),
     .write_hit_cnt_o(write_hit_cnt),
     .write_miss_cnt_o(write_miss_cnt)
     
     );

endmodule
