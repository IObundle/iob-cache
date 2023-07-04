`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_dmem 
  #(
    parameter ADDR_W        = 0,
    parameter DATA_W        = 0,
    parameter NWAYS_W       = 0,
    parameter NLINES_W      = 0,
    parameter WORD_OFFSET_W = 0,
    parameter REPLACE_POL    = 0,
    //derived cache parameters
    parameter TAG_W = ADDR_W - (WORD_OFFSET_W + NLINES_W),
    parameter NWAYS = 1 << NWAYS_W,
    parameter BLKSZ = 1 << WORD_OFFSET_W,
    parameter LINE_W = DATA_W * BLKSZ,
    parameter NLINES = 1 << NLINES_W,
    //derived frontend interface parameters
    parameter NBYTES     = DATA_W/8,
    parameter NBYTES_W   = $clog2(NBYTES),
    //derived backend buffer interface parameters (width: LINE_W)
    parameter BUF_ADDR_W = ADDR_W-WORD_OFFSET_W,
    parameter BUF_DATA_W = LINE_W,
    parameter BUF_NBYTES = LINE_W/8,
    //derived cache data memory parameters
    parameter DMEM_DATA_W = N_WAYS * LINE_W,
    parameter DMEM_ADDR_W = NLINES_W,
    parameter DMEM_NBYTES_W = DMEM_DATA_W/8,
    //derived cache tag memory parameters
    parameter TAG_DATA_W = TAG_W * NWAYS,
    parameter TAG_ADDR_W = NLINES_W
) (
    // front-end
//`include "iob_s_port.vs"

   // back-end buffer (can't use stub because of BUF_ADDR_W and BUF_DATA_W)
   output                    buf_iob_avalid_o,
   output [BUF_ADDR_W-1:0]   buf_iob_awaddr_o,
   output [BUF_DATA_W-1:0]   buf_iob_wdata_o,
   output [BUF_NBYTES_W-1:0] buf_iob_wstrb_o,
   output [BUF_DATA_W-1:0]   buf_iob_rdata_o,
   input                     buf_iob_ready_i,
   input                     buf_iob_rvalid_i,

   // write policy select: 0: write through, 1: write back
   input                     write_policy,

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
                             
                             `include "iob_clkrsten_port.vs"
   );
   
  // select way
   wire [NWAYS-1:0] way_hit_1hot, way_replace_1hot;
   wire [NWAYS_W-1:0] way_hit, way_replace;

   // address register
   wire [ADDR_W-1:WORD_OFFSET_W] addr_r;

   // write strobe register
   wire [NBYTES-1:0] wstrb_r;

   // tag
   wire [TAG_W-1:0] tag = iob_addr_i[ADDR_W-1-:TAG_W];
   wire [TAG_W-1:0] tag_r = addr_r[ADDR_W-1-:TAG_W];

   //index
   wire [NLINES_W-1:0] index = iob_addr_i[ADDR_W-1-TAG_W-:NLINES_W];
   wire [NLINES_W-1:0] index_r = addr_r[ADDR_W-1-TAG_W-:NLINES_W];

   //word offset
   wire [WORD_OFFSET_W-1:0] word_offset = iob_addr_i[WORD_OFFSET_W-1:0];
   wire [WORD_OFFSET_W-1:0] word_offset_r = addr_r[WORD_OFFSET_W-1:0];

   
   // external data memory interface NWAYS*LINE_W X NLINES
   assign data_mem_en_o = iob_avalid_o | buf_iob_rvalid_i;
   assign data_mem_addr_o = buf_iob_rvalid_i? index_r: index;
   assign data_mem_d_o = buf_iob_rvalid_i? {NWAYS{buf_iob_rdata_o}}: {NWAYS*BLKSZ{iob_wdata_o}};
   assign data_mem_we_o = buf_iob_rvalid_i? {BLKSZ*NBYTES*{1'b1}} << way_replace: wstrb_r << (way_hit*BLKSZ+word_offset_r)*NBYTES;
   

   wire [DMEM_DATA_W-1:0] dmem_d_i = data_mem_d_i >> ((way_hit*LINE_W)+(word_offset_r*DATA_W));
   assign iob_rdata_o =  dmem_d_i[DATA_W-1:0];
   assign iob_ready_o = buf_iob_ready_i;


   //compare tag_r with tags read from memory
   genvar                        i;
   generate
      for (i=1; i<=NWAYS; i=i+1) begin: way
         way_hit_1hot[i] = (tag_r == data_mem_d_i[i*(TAG_W+BLKSZ*DATA_W)-1-:TAG_W]);
      end
   endgenerate
   

   //hit or miss
   wire                           rd_en = iob_avalid_o & ~|iob_wstrb_i;
   wire                           wr_en = iob_avalid_o & |iob_wstrb_i;
   wire                           rd_en_r;
   wire                           wr_en_r;

   assign wr_hit_o = wr_en_r & |way_hit;
   assign wr_miss_o = wr_en_r & ~|way_hit;
   assign rd_hit_o = rd_en_r & |way_hit;
   assign rd_miss_o = rd_en_r & ~|way_hit;

   wire miss = wr_miss_o | rd_miss_o;
   
   //valid bit for each line in each way
   wire [NWAYS*NLINES-1:0] valid_bit;
   wire [NWAYS*NLINES_W-1:0] valid_bit_int = valid_bit | (rd_en << (way_hit*NLINES + addr_i[NLINES_W-1:0]));

   //back-end buffer interface
   assign buf_iob_avalid_o = write_policy == `IOB_CACHE_WRITE_BACK? miss : rd_miss_o;
   assign buf_iob_addr_o = addr_i[ADDR_W-1:WORD_OFFSET_W];
   assign buf_wdata_o = data_mem_d_i >> (way_replace*BLKSZ*DATA_W);
   assign buf_wstrb_o = write_policy == `IOB_CACHE_WRITE_BACK && buf_iob_ready_i? {BLKSZ*NBYTES{1'b1}} : {BLKSZ*NBYTES{1'b0}};

   assign iob_ready = buf_iob_ready_i & ~miss;
   assign buf_iob_rvalid_i = buf_iob_rvalid_i & ~miss;

   //convert way_hit 1-hot encoding to binary encoding
   iob_prio_encoder #(
       .DATA_W(NWAYS)
   ) prio_encoder (
       .unencoded_i(way_hit_1hot),
       .encoded_o(way_hit)
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
   iob_reg_re (
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
   wire req_reg_en = iob_avalid_i & iob_ready_o;

   //address register
   iob_reg #(
      .DATA_W(TAG_W+NLINES_W)
      .RST_VAL(0)
   ) addr_reg (
      .clk_i(clk_i),
      .cke_i(cke_i),
      .arst_i(arst_i),
      .en_i(req_reg_en),
      .d_i(addr_i[ADDR_W-1:WORD_OFFSET_W]),
      .d_o(addr_r)
   );

   //write strobe register
   iob_reg #(
         .DATA_W(NBYTES)
      ) wstrb_reg (
         .clk(clk),
         .rst(rst),
                   .cke(1'b1),
         .d_i(iob_wstrb_i),
         .d_o(wstrb_r),
      );
   
   assign tag_r = addr_r[ADDR_W-1-:TAG_W];

endmodule

