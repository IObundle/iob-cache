`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_dmem #(
    parameter ADDR_W        = 0,
    parameter DATA_W        = 0,
    parameter NWAYS_W       = 0,
    parameter NLINES_W      = 0,
    parameter TAG_W         = 0,
    parameter WORD_OFFSET_W = 0,
    parameter WRITE_POL     = 0,
    parameter REPLACE_POL    = 0,
    parameter NBYTES     = 0,
    parameter NBYTES_W   = 0,
    parameter DMEM_DATA_W = 2**N_WAYS_W * (TAG_W + DATA_W)
) (
    // front-end
   `include "iob_s_port.vs"

   // back-end (can't use stub because of ADDR_W and DATA_W)   
    output                               be_iob_avalid_o,
    output [ADDR_W-WORD_OFFSET_W-1:0]    be_iob_awaddr_o,
    output [2**WORD_OFFSET_W*DATA_W-1:0] be_iob_wdata_o,
    output [2**WORD_OFFSET*NBYTES_W-1:0] be_iob_wstrb_o,
    output [2**WORD_OFFSET_W*DATA_W-1:0] be_iob_rdata_o,
    input                                be_iob_ready_i,
    input                                be_iob_rvalid_i,


   //interface to external memory
    output                               data_mem_en_o,
    output [2**WORD_OFFSET_W*NBYTES-1:0] data_mem_we_o,
    output [NLINES_W-1:0]                data_mem_addr_o,
    output [2**WORD_OFFSET_W*DATA_W-1:0] data_mem_d_o,
    input [2**WORD_OFFSET_W*DATA_W-1:0]  data_mem_d_i,
   
    // cache-control
    input                                invalidate_i,
    output                               wr_hit_o,
    output                               wr_miss_o,
    output                               rd_hit_o,
    output                               rd_miss_o,

   `include "iob_clkrsten_port.vs"
);

   localparam NWAYS = 2 ** NWAYS_W;
   
  // select way
   wire [NWAYS-1:0] way_hit_1hot, way_replace_1hot;
   wire [NWAYS_W-1:0] way_hit, way_replace;

  // extract tag from address
   wire [TAG_W-1:0] tag = iob_addr_i[ADDR_W-1:N LINES_W+WORD_OFFSET_W];
   wire [TAG_W-1:0] tag_r;
   
   
   // external data memory interface
   assign data_mem_en_o = iob_avalid_o;
   assign data_mem_addr_o = addr_i[ADDR_W-TAG_W-1-:NLINES_W];
   assign data_mem_d_o = {NWAYS*(2**WORD_OFFSET_W){tag, wdata_i}};
   assign data_mem_we_o = wstrb_i << (iob_addr_i[WORD_OFFSET_W-1:0]*way_hit*(TAG_W+DATA_W));
   assign iob_rdata_o = data_mem_d_i >> (iob_addr_i[WORD_OFFSET_W-1:0]*way_hit*(TAG_W+DATA_W));


   //compare tar_r with tags read from memory
   genvar           i;   
   generate
      for (i=0; i<NWAYS; i=i+1) begin: way
         way_hit_1hot[i] = (tag_r == data_mem_d_i[(i+1)*(TAG_W+DATA_W)-1:i*(TAG_W+DATA_W)]);
      end
   endgenerate
   

   // get way hit
   iob_prio_encoder #(
       .DATA_W(NWAYS)
   ) prio_encoder (
       .unencoded_i(way_hit_1hot),
       .encoded_o(way_hit)
   );

   wire                           rd_en = iob_avalid_o & ~|iob_wstrb_i;
   wire                           wr_en = iob_avalid_o & |iob_wstrb_i;
   wire                           rd_en_r;
   wire                           wr_en_r;

   assign wr_hit_o = wr_en_r & |way_hit;
   assign wr_miss_o = wr_en_r & ~|way_hit;
   assign rd_hit_o = rd_en_r & |way_hit;
   assign rd_miss_o = rd_en_r & ~|way_hit;
   
   //valid bit for each line in each way
   wire [NWAYS*(2**NLINES_W)-1:0] valid_bit;
   wire [NWAYS*(2**NLINES_W)-1:0] valid_bit_int = valid_bit | (rd_en << (way_hit*(2**NLINES_W) + addr_i[NLINES_W-1:0]));



   iob_reg #(
       .DATA_W(1                  )
   ) rd_en_reg (
       .clk_i(clk_i),
                .cke_i(cke_i),
       .arst_i(arst_i),
       .d_i(rd_en),
       .d_o(rd_en_r)
   );

   iob_reg #(
       .DATA_W(1                  )
   ) wr_en_reg (
       .clk_i(clk_i),
                .cke_i(cke_i),
       .arst_i(arst_i),
       .d_i(wr_en),
       .d_o(wr_en_r)
   );
   
   
   iob_reg_re (
      .DATA_W(NWAYS*(2**NLINES_W)),
      .RST_VAL(0)
   ) valid_reg (
      .clk_i(clk_i),
                .cke_i(cke_i),
      .arst_i(arst_i),
      .rst_i(invalidate_i),
      .en_i(rd_en),
      .d_i(valid_bit_int),
      .d_o(valid_bit)
   );

   //tag register
   iob_reg #(
      .DATA_W(NWAYS*(2**NLINES_W)),
      .RST_VAL(0)
   ) valid_reg (
      .clk_i(clk_i),
      .arst_i(arst_i),
      .d_i(tag),
      .d_o(tag_r),
      .we_i(iob_valid_i),
      .q_o(valid_bit)
   );
endmodule

