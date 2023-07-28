`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache
  #(
    parameter FE_ADDR_W = 0,
    parameter FE_DATA_W = 0,
    parameter FE_NBYTES = 0,
    parameter NWAYS_W = 0,
    parameter NLINES_W = 0,
    parameter NWORDS_W = 0,
    parameter BE_RATIO = 0,
    //the following parameters cannot be deived because they are needed on the top-level interface
    parameter NWAYS = 0,
    parameter LINE_W = 0,
    parameter TAG_W = 0,
    parameter DMEM_DATA_W = 32,
    parameter DMEM_NBYTES = 4
) (
   //clock, enable, reset
`include "clk_en_rst_port.vs"

   // front-end interface
`include "fe_iob_s_port.vs"

   // internal interface
`include "be_iob_m_port.vs"

    //interface to cache monitor
   input                     invalidate_i,
   output                    wr_hit_o,
   output                    wr_miss_o,
   output                    rd_hit_o,
   output                    rd_miss_o,

   //interface to external data memory
   output                    data_mem_en_o,
   output [DMEM_NBYTES-1:0]  data_mem_we_o,
   output [NLINES_W-1:0]     data_mem_addr_o,
   output [DMEM_DATA_W-1:0]  data_mem_d_o,
   input [DMEM_DATA_W-1:0]   data_mem_d_i,
   
   //interface to external tag memory
   output                   tag_mem_en_o,
   output [NWAYS_W-1:0]     tag_mem_we_o,
   output [NLINES_W-1:0]    tag_mem_addr_o,
   output [NWAYS*TAG_W-1:0] tag_mem_d_o,
   input [NWAYS*TAG_W-1:0]  tag_mem_d_i
   
   );

   //number of words in cache line
   localparam NWORDS = 2**NWORDS_W;
   
   //number of back-end words in cache line
   localparam BE_NWORDS = 2**(NWORDS_W-BE_RATIO_W);

   //number of words in back-end interface (log2)
   localparam NWORDS_IN_BE_W=$clog2(BE_DATA_W/FE_DATA_W);
   
   
   // select way
   wire [NWAYS-1:0]          way_hit_1hot, way_replace_1hot;
   wire [NWAYS_W-1:0]        way_hit, way_replace;


   //request word
   localparam REQ_W = 1+FE_ADDR_W+FE_NBYTES+FE_DATA_W;
   wire [REQ_W-1:0] req = {fe_iob_avalid_i, fe_iob_addr_i, fe_iob_wstrb_i, fe_iob_wdata_i};   
   wire [REQ_W-1:0] req_r;

   //tag register
   wire tag_r = req_r[REQ_W-2-:TAG_W];

   //index
   wire [NLINES_W-1:0] index = req_[REQ_W-2-TAG_W-:NLINES_W];
   wire [NLINES_W-1:0] index_r = req_r[REQ_W-2-TAG_W-:NLINES_W];

   // word offset register
   wire [NWORDS_W-1:0] word_offset_r = req_r[REQ_W-2-TAG_W-NLINES_W-:NWORDS_W];

   // write strobe
   wire [NBYTES-1:0]   wstrb_r = req_r[FE_DATA_W+:FE_NBYTES];

   // write data
   wire [FE_DATA_W-1:0] wdata_r = req_r[FE_DATA_W-1:0];

   //be word offset in cache line
   wire [BE_RATIO_W-1:0] be_word_offset;

   //update cache data memory on a write hit 
   wire [NWAYS*NWORDS*FE_NBYTES-1:0] hit_wstrb = (wstrb_r << word_offset_r) << (way_hit*LINE_W);
   wire [NWAYS*NWORDS*FE_DATA_W-1:0] hit_wdata = (wdata_r << word_offset_r) << (way_hit*LINE_W);

   
   //update cache data memory with replace data
   wire [NWAYS*NWORDS*FE_NBYTES-1:0] replace_wstrb = ({BE_NWORDS*FE_BYTES{1'b1}} << be_word_offset) << (way_hit*LINE_W);
   wire [NWAYS*NWORDS*FE_DATA_W-1:0] replace_wdata = (be_iob_rdata_i << be_word_offset) << (way_hit*LINE_W);

   //extract read enable
   wire rd_en = fe_iob_avalid_i & !fe_iob_wstrb_i;
   wire rd_en_r = req_r[REQ_W-1] & !wstrb_r;

   //extract write enable
   wire wr_en = fe_iob_avalid_i & |fe_iob_wstrb_i;
   wire wr_en_r = req_r[REQ_W-1] & |wstrb_r;
   
   //cache hit
   assign wr_hit_o = wr_en_r & |way_hit;
   assign rd_hit_o = rd_en_r & |way_hit;

   //data memory interface
   wire replace_en;
   assign data_mem_en_o = rd_en | (wr_en_r & wr_hit_o) | replace_en;
   assign data_mem_addr_o = fe_iob_avalid_i? index : index_r;
   assign data_mem_we_o = (wr_en_r & wr_hit_o)? hit_wstrb : replace_wstrb;
   assign data_mem_d_o = (wr_en_r & wr_hit_o)? hit_wdata : replace_wdata;

   //tag memory interface
   assign tag_mem_en_o = fe_iob_avalid_i | replace_en;
   assign tag_mem_addr_o = fe_iob_avalid_i? index : index_r;
   assign tag_mem_we_o = replace_en << way_hit;
   assign tag_mem_d_o = req_r[REQ_W-2-:TAG_W] << (way_hit*TAG_W);
   

   // front-end response bus 
   wire [DMEM_DATA_W-1:0]        dmem_d_i = data_mem_d_i >> ((way_hit*LINE_W)+(word_offset_r*FE_DATA_W));
   assign fe_iob_rdata_o =  dmem_d_i[FE_DATA_W-1:0];
   assign fe_iob_ready_o = be_iob_ready_i & wr_miss_o;
   wire                           fe_rvalid;
   assign fe_iob_rvalid_o = fe_rvalid;

   //compute cache hit by comparaing tag_r with tags read from memory
   genvar                        i;
   generate
      for (i=1; i<=NWAYS; i=i+1) begin: way
         assign way_hit_1hot[i] = (tag_r == data_mem_d_i[i*(TAG_W+BLKSZ*FE_DATA_W)-1-:TAG_W]);
      end
   endgenerate
   

   //cache miss
   assign wr_miss_o = wr_en_r & ~|way_hit;
   assign rd_miss_o = rd_en_r & ~|way_hit;

   wire                           miss = wr_miss_o | rd_miss_o;
   
   //valid bit for each line in each way
   wire [NWAYS*NLINES-1:0]        valid_bit;
   wire [NWAYS*NLINES_W-1:0]      valid_bit_nxt = valid_bit | (replace_en << (way_hit*NLINES + index_r));
   
   //back-end buffer interface
   reg                            replacing;
   assign be_iob_avalid_o = replacing | wr_en;
   assign be_iob_addr_o = replacing? replace_addr : be_iob_addr_i[FE_ADDR_W-1: NWORDS_IN_BE_W];
   assign be_iob_wdata_o = fe_iob_wdata_i << (be_iob_addr_i[NWORDS_IN_BE_W-1:0]*FE_DATA_W);
   assign be_iob_wstrb_o = fe_iob_wstrb_i << (be_iob_addr_i[NWORDS_IN_BE_W-1:0]*FE_NBYTES);

   //convert way_hit 1-hot encoding to binary encoding
   iob_prio_enc #(
       .W(NWAYS)
   ) way_hit_enc (
       .unencoded_i(way_hit_1hot),
       .encoded_o(way_hit)
   );

   //convert way_replace 1-hot encoding to binary encoding
   iob_prio_enc #(
       .W(NWAYS)
   ) way_replace_enc (
       .unencoded_i(way_replace_1hot),
       .encoded_o(way_replace)
   );


   iob_reg_e #(
      .DATA_W(FE_ADDR_W-NWORDS_W),
      .RST_VAL(0)
   ) addr_reg (
      .clk_i(clk_i),
      .cke_i(cke_i),
      .arst_i(arst_i),
      .en_i(req_en),
      .d_i(addr_i[FE_ADDR_W-1:NWORDS_W]),
      .d_o(addr_r)
   );

   wire ack;
   iob_reg #(
      .DATA_W(1),
      .RST_VAL(0)
   ) ack_reg (
      .clk_i(clk_i),
      .cke_i(cke_i),
      .arst_i(arst_i),
      .d_i(req_en),
      .d_o(ack)
   );

   
   //request register
   iob_reg_e 
     #(
       .DATA_W(REQ_W),
       .RST_VAL(0)
       ) 
   req_reg (
              .clk(clk_i),
              .arst(arst_i),
              .cke(cke_i),
              .en_i(fe_iob_avalid_i),
              .d_i(req),
              .d_o(req_r)
              );
   
   //valid register
   iob_reg_e 
     #(
       .DATA_W(REQ_W),
       .RST_VAL(0)
       ) 
   req_reg (
              .clk(clk_i),
              .arst(arst_i),
              .cke(cke_i),
              .en_i(replace_en),
              .d_i(valid_bit_nxt),
              .d_o(valid_bit)
              );

   //front-end read valid register
   iob_reg
     #(
       .DATA_W(1),
       .RST_VAL(0)
       )
   fe_rvalid_reg (
                  .clk(clk_i),
                  .arst(arst_i),
                  .cke(cke_i),
                  .d_i(replace_en),
                  .d_o(fe_rvalid)
                  );

endmodule

