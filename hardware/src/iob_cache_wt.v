`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_wt
  #(
`include "iob_cache_params.vs"
    ) 
   (
`include "iob_cache_io.vs"
    );

   // wire declarations
   wire iob_ready_nxt_o;
   wire iob_rvalid_nxt_o;
   wire write_hit;
   wire write_miss;
   wire read_hit;
   wire read_miss;
`include "be_iob_wire.vs"


   //sofware acessible registers
`include "iob_cache_swreg_inst.vs"

   //cache engine   
   iob_cache 
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),
       .FE_NBYTES(FE_NBYTES),
       .NWAYS_W(NWAYS_W),
       .NWAYS(NWAYS),
       .NLINES_W(NLINES_W),
       .LINE_W(LINE_W),
       .NWORDS_W(NWORDS_W),
       .BE_RATIO_W(BE_RATIO_W),
       .TAG_W(TAG_W),
       .DMEM_DATA_W(DMEM_DATA_W),
       .DMEM_NBYTES(DMEM_NBYTES),
       .TAGMEM_DATA_W(TAGMEM_DATA_W)
  ) 
   cache
     (
      //clock, enable and reset
`include "clk_en_rst_portmap.vs"

      // front-end interface
`include "fe_iob_s_s_portmap.vs"
      .iob_ready_nxt_o(),
      .iob_rvalid_nxt_o(),
      // back-end interface
`include "be_iob_m_m_portmap.vs"

      //data memory interface
      .data_mem_en_o (data_mem_en_o),
      .data_mem_we_o (data_mem_we_o),
      .data_mem_addr_o(data_mem_addr_o),
      .data_mem_d_o(data_mem_d_o),
      .data_mem_d_i(data_mem_d_i),

      //tag memory interface
      .tag_mem_en_o (tag_mem_en_o),
      .tag_mem_we_o (tag_mem_we_o),
      .tag_mem_addr_o(tag_mem_addr_o),
      .tag_mem_d_o(tag_mem_d_o),
      .tag_mem_d_i(tag_mem_d_i),

      // control and status signals
      .invalidate_i    (INVALIDATE),
      .write_hit_o     (write_hit),
      .write_miss_o    (write_miss),
      .read_hit_o      (read_hit),
      .read_miss_o     (read_miss)
  );

   //back-end module
   iob_cache_backend 
     #(
       .BE_ADDR_W    (BE_ADDR_W),
       .BE_DATA_W    (BE_DATA_W),
       .WRITE_POL    (WRITE_POL),
       .WTB_DEPTH_W  (WTB_DEPTH_W)
       ) 
   back_end 
     (
      //clock, enable and reset
`include "clk_en_rst_portmap.vs"
      //internal interface
`include "be_iob_s_portmap.vs"
`include "be_iob_m_m_portmap.vs"
      );
   
   iob_cache_monitor 
     #(
       .DATA_W(DATA_W),
       .ADDR_W(ADDR_W)
       ) cache_monitor 
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
