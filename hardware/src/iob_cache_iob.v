`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_iob 
  #(
    `include "iob_cache_params.vs"
) (
    `include "iob_cache_io.vs"
);
    //derived parameters
   localparam NBYTES        = DATA_W / 8;
   localparam NBYTES_W      = $clog2(NBYTES);
   localparam FE_NBYTES     = FE_DATA_W / 8;
   localparam FE_NBYTES_W   = $clog2(FE_NBYTES);
   localparam BE_NBYTES     = BE_DATA_W / 8;
   localparam BE_NBYTES_W   = $clog2(BE_NBYTES);
   localparam LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W);
   


  // back-end write-channel
   wire write_req;
   wire write_ack;
   wire [                   FE_ADDR_W-1:FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr;
   wire [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 : 0] write_wdata;
   wire [                                                       FE_NBYTES-1:0] write_wstrb;
   
  // back-end read-channel
   wire                                                                        read_req;
   wire [FE_ADDR_W -1:BE_NBYTES_W+LINE2BE_W]                                   read_req_addr;
   wire                                                                        read_valid;
   wire [                     LINE2BE_W-1:0]                                   read_addr;

   
   
   //IOb wires to coonect sw regs
    `include "iob_wire.vs"
   assign iob_avalid   = iob_avalid_i;
   assign iob_addr     = iob_addr_i;
   assign iob_wstrb    = iob_wstrb_i;
   assign iob_wdata    = iob_wdata_i;
   assign iob_ready_o  = iob_ready;
   assign iob_rvalid_o = iob_rvalid;
   assign iob_rdata_o  = iob_rdata;
   
   //Sofware acessible registers
    `include "iob_cache_swreg_inst.vs"
   
   //events
   wire                                     write_hit;
   wire                                     write_miss;
   wire                                     read_hit;
   wire                                     read_miss;
   
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
      .clk_i    (clk_i),
      .arst_i   (arst_i),

      // front-end read/write 
      .avalid_i (fe_iob_avalid_i),
      .addr_i   (fe_iob_addr_i),
      .wdata_i  (fe_iob_wdata_i),
      .wstrb_i  (fe_iob_wstrb_i),
      .rdata_o  (fe_iob_rdata_o),
      .rvalid_o (fe_iob_rvalid_o),
      .ready_o  (fe_iob_rdata_o),

      // back-end write request
      .write_req_o   (write_req),
      .write_addr_o  (write_addr),
      .write_wdata_o (write_wdata),
      .write_wstrb_o (write_wstrb),
      .write_ack_i   (write_ack),
                  
      // back-end read reques
      .read_req_o      (read_req),
      .read_req_addr_o (read_req_addr),
      .read_valid_i    (read_valid),
      .read_addr_i     (read_addr),
      .read_rdata_i    (be_iob_rdata_i),

      // controla and status signals
      .wtbuf_empty_o   (WTB_EMPTY),
      .wtbuf_full_o    (WTB_FULL),
      .invalidate_i    (INVALIDATE),

      //event signals
      .write_hit_o     (write_hit),
      .write_miss_o    (write_miss),
      .read_hit_o      (read_hit),
      .read_miss_o     (read_miss)
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
      .write_req_i   (write_req),
      .write_addr_i  (write_addr),
      .write_wdata_i   (write_wdata),
      .write_wstrb_i   (write_wstrb),
      .write_ack_o   (write_ack),
      // cache-line replacement (read-channel)
      .read_req_i (read_req),
      .read_req_addr_i(read_req_addr),
      .read_valid_o    (read_req),
      .read_addr_o   (read_addr),
      // back-end native interface
      .be_iob_avalid_o(be_iob_avalid_o),
      .be_iob_addr_o  (be_iob_addr_o),
      .be_iob_wdata_o (be_iob_wdata_o),
      .be_iob_wstrb_o (be_iob_wstrb_o),
      .be_iob_rvalid_i(be_iob_rvalid_i),
      .be_iob_rdata_i (be_iob_rdata_i),
      .be_iob_ready_i (be_iob_ready_i),
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

     //monitored events
     .write_hit_i (write_hit),
     .write_miss_i(write_miss),
     .read_hit_i  (read_hit),
     .read_miss_i (read_miss),

     //control and status signals
     .reset_counters_i(RESET_COUNTERS),
     .read_hit_cnt_o (READ_HIT_CNT),
     .read_miss_cnt_o(READ_MISS_CNT),
     .write_hit_cnt_o(WRITE_HIT_CNT),
     .write_miss_cnt_o(WRITE_MISS_CNT)
     
     );

endmodule
