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
       .BE_ADDR_W(BE_ADDR_W),
       .BE_DATA_W(BE_DATA_W),
       .BE_NBYTES(BE_NBYTES),
       .NWAYS_W(NWAYS_W),
       .NWAYS(NWAYS),
       .NSETS_W(NSETS_W),
       .BLK_SIZE_W(BLK_SIZE_W),
       .TAG_W(TAG_W),
       .LINE_W(LINE_W),
       .DATA_ADDR_W(DATA_ADDR_W),
       .DATA_DATA_W(DATA_DATA_W),
       .TAG_ADDR_W(DATA_ADDR_W),
       .TAG_DATA_W(TAG_DATA_W)
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
`include "data_ram_sp_be_portmap.vs"
      //tag memory interface
`include "tag_ram_sp_portmap.vs"
      // control and status signals
      .invalidate_i    (INVALIDATE),
      .wr_hit_o     (write_hit),
      .wr_miss_o    (write_miss),
      .rd_hit_o      (read_hit),
      .rd_miss_o     (read_miss)
  );

   //back-end module
   iob_cache_backend 
     #(
       .BE_ADDR_W    (BE_ADDR_W),
       .BE_DATA_W    (BE_DATA_W),
       .WTB_ADDR_W   (WTB_ADDR_W),
       .WTB_DATA_W   (WTB_DATA_W),
       .WRITE_POL    (WRITE_POL)
       ) 
   back_end 
     (
      //clock, enable and reset
`include "clk_en_rst_portmap.vs"
      //internal interface
`include "be_iob_s_portmap.vs"
`include "be_iob_m_m_portmap.vs"
`include "wtb_ram_2p_portmap.vs"
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
