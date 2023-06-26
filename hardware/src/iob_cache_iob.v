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
   
   wire data_req;
   wire data_ack;
   wire [FE_ADDR_W-1:FE_NBYTES_W] data_addr;
   wire [FE_DATA_W-1 : 0]         data_wdata, data_rdata;
   wire [FE_NBYTES-1:0]           data_wstrb;


   //events
   wire                write_hit, write_miss, read_hit, read_miss;

  // back-end write-channel
   wire                write_req;
   wire                write_ack;
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
   
   //IOB data transfer wires
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
      .arst_i(arst_i),

      // front-end read / write 
      .req_i    (data_req),
      .addr_i   (data_addr),
      .wdata_i  (data_wdata),
      .wstrb_i  (data_wstrb),
      .rdata_o    (data_rdata),
      .ack_o      (data_ack),

      // back-end write command
      .write_req_o (write_req),
      .write_addr_o(write_addr),
      .write_wdata_o (write_wdata),
      .write_wstrb_o (write_wstrb),
      .write_ack_i   (write_ack),
                  
      // back-end read command
      .replace_req_o (replace_req),
      .replace_addr_o(replace_addr),
      .replace_i       (replace),
      .read_req_i    (read_req),
      .read_addr_i   (read_addr),
      .read_rdata_i    (read_rdata),

      // control signals
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
      .write_valid_i   (write_req),
      .write_addr_i  (write_addr),
      .write_wdata_i   (write_wdata),
      .write_wstrb_i   (write_wstrb),
      .write_ack_o   (write_ack),
      // cache-line replacement (read-channel)
      .replace_valid_i (replace_req),
      .replace_addr_i(replace_addr),
      .replace_o       (replace),
      .read_valid_o    (read_req),
      .read_addr_o   (read_addr),
      .read_rdata_o    (read_rdata),
      // back-end native interface
   `include "be_iob_m_portmap.vs"
   `include "iob_clkenrst_portmap.vs"

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
