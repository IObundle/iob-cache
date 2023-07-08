`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_dmem 
  #(
    parameter FE_ADDR_W        = 0,
    parameter FE_DATA_W        = 0,
    parameter NWAYS_W       = 0,
    parameter NLINES_W      = 0,
    parameter WORD_OFFSET_W = 0,
    parameter WRITE_POL    = 0,
    parameter REPLACE_POL    = 0,
    //derived cache parameters
    parameter NWAYS = 1 << NWAYS_W,
    parameter BLKSZ = 1 << WORD_OFFSET_W,
    parameter LINE_W = FE_DATA_W * BLKSZ,
    parameter NLINES = 1 << NLINES_W,
    parameter NBYTES     = FE_DATA_W/8,
    //derived backend buffer interface parameters
    parameter BUF_ADDR_W = FE_ADDR_W-WORD_OFFSET_W,
    parameter BUF_DATA_W = LINE_W,
    parameter BUF_NBYTES = LINE_W/8,
    //derived cache data memory parameters
    parameter DMEM_DATA_W = NWAYS * LINE_W,
    parameter DMEM_ADDR_W = NLINES_W,
    parameter DMEM_NBYTES = DMEM_DATA_W/8,
    //derived cache tag memory parameters
    parameter TAG_W = FE_ADDR_W - (WORD_OFFSET_W + NLINES_W),
    parameter TAG_DATA_W = TAG_W * NWAYS,
    parameter TAG_ADDR_W = NLINES_W
) (
    // front-end
`include "fe_iob_s_port.vs"

    // back-end
`include "buf_iob_m_port.vs"


   //interface to external data memory
   output                    data_mem_en_o,
   output [DMEM_NBYTES-1:0]  data_mem_we_o,
   output [DMEM_ADDR_W-1:0]  data_mem_addr_o,
   output [DMEM_DATA_W-1:0]  data_mem_d_o,
   input [DMEM_DATA_W-1:0]   data_mem_d_i,
   
   //interface to external tag memory
   output                    tag_mem_en_o,
   output                    tag_mem_we_o,
   output [TAG_ADDR_W-1:0]   tag_mem_addr_o,
   output [TAG_DATA_W-1:0]   tag_mem_d_o,
   input [TAG_DATA_W-1:0]    tag_mem_d_i,
   
    // cache-control
   input                     invalidate_i,
   output                    wr_hit_o,
   output                    wr_miss_o,
   output                    rd_hit_o,
   output                    rd_miss_o,
                             
`include "iob_clkenrst_port.vs"
   );
   
  // select way
   wire [NWAYS-1:0]          way_hit_1hot, way_replace_1hot;
   wire [NWAYS_W-1:0]        way_hit, way_replace;
   
   // address register
   wire [FE_ADDR_W-1:WORD_OFFSET_W] addr_r;
   
   // write strobe register
   wire [NBYTES-1:0]             wstrb_r;
   
   // tag
   wire [TAG_W-1:0]              tag = fe_iob_addr_i[FE_ADDR_W-1-:TAG_W];
   wire [TAG_W-1:0]              tag_r = addr_r[FE_ADDR_W-1-:TAG_W];
   
   //index
   wire [NLINES_W-1:0]           index = fe_iob_addr_i[FE_ADDR_W-1-TAG_W-:NLINES_W];
   wire [NLINES_W-1:0]           index_r = addr_r[FE_ADDR_W-1-TAG_W-:NLINES_W];
   
   //word offset
   wire [WORD_OFFSET_W-1:0]      word_offset = fe_iob_addr_i[WORD_OFFSET_W-1:0];
   wire [WORD_OFFSET_W-1:0]      word_offset_r = addr_r[WORD_OFFSET_W-1:0];
   
   
   // external data memory interface NWAYS*LINE_W X NLINES
   assign data_mem_en_o = fe_iob_avalid_o | buf_iob_rvalid_i;
   assign data_mem_addr_o = buf_iob_rvalid_i? index_r: index;
   assign data_mem_d_o = buf_iob_rvalid_i? {NWAYS{buf_iob_rdata_o}}: {NWAYS*BLKSZ{fe_iob_wdata_o}};
   assign data_mem_we_o = buf_iob_rvalid_i? {BLKSZ*NBYTES*{1'b1}} << way_replace: wstrb_r << (way_hit*BLKSZ+word_offset_r)*NBYTES;
   

   wire [DMEM_DATA_W-1:0]        dmem_d_i = data_mem_d_i >> ((way_hit*LINE_W)+(word_offset_r*FE_DATA_W));
   assign fe_iob_rdata_o =  dmem_d_i[FE_DATA_W-1:0];
   assign fe_iob_ready_o = buf_iob_ready_i;


   //compare tag_r with tags read from memory
   genvar                        i;
   generate
      for (i=1; i<=NWAYS; i=i+1) begin: way
         assign way_hit_1hot[i] = (tag_r == data_mem_d_i[i*(TAG_W+BLKSZ*FE_DATA_W)-1-:TAG_W]);
      end
   endgenerate
   

   //hit or miss
   wire                           rd_en = fe_iob_avalid_o & ~|fe_iob_wstrb_i;
   wire                           wr_en = fe_iob_avalid_o & |fe_iob_wstrb_i;
   wire                           rd_en_r;
   wire                           wr_en_r;

   assign wr_hit_o = wr_en_r & |way_hit;
   assign wr_miss_o = wr_en_r & ~|way_hit;
   assign rd_hit_o = rd_en_r & |way_hit;
   assign rd_miss_o = rd_en_r & ~|way_hit;

   wire                           miss = wr_miss_o | rd_miss_o;
   
   //valid bit for each line in each way
   wire [NWAYS*NLINES-1:0]        valid_bit;
   wire [NWAYS*NLINES_W-1:0]      valid_bit_int = valid_bit | (rd_en << (way_hit*NLINES + addr_i[NLINES_W-1:0]));
   
   //back-end buffer interface
   assign buf_iob_addr_o = addr_i[FE_ADDR_W-1:WORD_OFFSET_W];
   assign buf_iob_wdata_o = data_mem_d_i >> (way_replace*BLKSZ*FE_DATA_W);
   generate 
      if (WRITE_POL == `IOB_CACHE_WRITE_BACK) begin: g_wb
         assign buf_iob_avalid_o = miss;
         assign buf_iob_wstrb_o = {BLKSZ*NBYTES{1'b1}};
      end
      else begin: g_wt
         assign buf_iob_avalid_o = rd_miss_o;
         assign buf_iob_wstrb_o = {BLKSZ*NBYTES{1'b0}};
      end
   endgenerate
   
   assign fe_iob_ready_o = buf_iob_ready_i & ~miss;
   assign buf_iob_rvalid_i = buf_iob_rvalid_i & ~miss;

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

   //front-end read enable register
   iob_reg #(
       .DATA_W(1                  )
   ) rd_en_reg (
       .clk_i(clk_i),
                .cke_i(cke_i),
       .arst_i(arst_i),
       .d_i(rd_en),
       .d_o(rd_en_r)
   );

   //front-end write enable register
   iob_reg #(
       .DATA_W(1                  )
   ) wr_en_reg (
       .clk_i(clk_i),
                .cke_i(cke_i),
       .arst_i(arst_i),
       .d_i(wr_en),
       .d_o(wr_en_r)
   );   

   //valid bit register
   iob_reg_re #(
      .DATA_W(NWAYS*NLINES),
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
   wire req_en = fe_iob_avalid_i & fe_iob_ready_o;

   //address register
   iob_reg_e #(
      .DATA_W(TAG_W+NLINES_W),
      .RST_VAL(0)
   ) addr_reg (
      .clk_i(clk_i),
      .cke_i(cke_i),
      .arst_i(arst_i),
      .en_i(req_en),
      .d_i(addr_i[FE_ADDR_W-1:WORD_OFFSET_W]),
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

   
   //write strobe register
   iob_reg_e 
     #(
       .DATA_W(NBYTES),
       .RST_VAL(0)
       ) 
   wstrb_reg (
              .clk(clk_i),
              .arst(arst_i),
              .cke(cke_i),
              .en_i(req_en),
              .d_i(fe_iob_wstrb_i),
              .d_o(wstrb_r)
              );
   
   assign tag_r = addr_r[FE_ADDR_W-1-:TAG_W];


   // line replace
   iob_cache_replace
     #(
       .NWAYS    (NWAYS),
       .NLINES_W  (NLINES_W),
       .REP_POLICY(REPLACE_POL)
       )
   replace_inst 
     (
      .clk_i         (clk_i),
      .arst_i        (arst_i),
      .cke(cke_i),
      .rst_i         (invalidate_i),
      .we_i          (ack),
      .way_hit_1hot_i     (way_hit_1hot),
      .way_hit_i     (way_hit),
      .line_addr_i   (index_reg[NLINES_W-1:0]),
      .way_select_o  (way_replace_1hot)
      );

endmodule

