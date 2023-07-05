`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_iob 
  #(
    `include "iob_cache_params.vs"
) (
    `include "iob_cache_io.vs"
);

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

   iob_cache_dmem #(
      .ADDR_W        (ADDR_W),
      .DATA_W        (DATA_W),
      .BE_DATA_W     (BE_DATA_W),
      .NWAYS_W       (NWAYS_W),
      .NLINES_W      (NLINES_W),
      .WORD_OFFSET_W (WORD_OFFSET_W),
      .WTBUF_DEPTH_W (WTBUF_DEPTH_W),
      .REPLACE_POL   (REPLACE_POL),
      .WRITE_POL     (WRITE_POL)
  ) dmem (
      .clk_i         (clk_i),
      .arst_i        (arst_i),

    // front-end interface
    `include "fe_iob_s_portmap.vs"

      // back-end interface
    `include "int_iob_portmap.vs"

          .ext_mem_w_en_o  (data_mem_w_en_o),
          .ext_mem_w_addr_o(data_mem_w_addr_o),
          .ext_mem_w_data_o(data_mem_w_data_o),

          .ext_mem_r_en_o  (data_mem_r_en_o),
          .ext_mem_r_addr_o(data_mem_r_addr_o),
          .ext_mem_r_data_i(data_mem_r_data_o),


          
      // control and status signals
      .invalidate_i    (INVALIDATE),
      .write_hit_o     (write_hit),
      .write_miss_o    (write_miss),
      .read_hit_o      (read_hit),
      .read_miss_o     (read_miss)
  );

   //Write through buffer
   iob_fifo_sync 
     #(
       .R_DATA_W(FE_ADDR_W+FE_DATA_W+NBYTES),
       .W_DATA_W(FE_ADDR_W+FE_DATA_W+NBYTES),
       .ADDR_W  (WTBUF_DEPTH_W)
       ) write_throught_buffer 
       (
        .clk_i (clk_i),
        .rst_i (arst_i),
        .arst_i(arst_i),
        .cke_i (1'b1),
        
        .ext_mem_w_en_o  (wtb_mem_w_en_o),
        .ext_mem_w_addr_o(wtb_mem_w_addr_o),
        .ext_mem_w_data_o(wtb_mem_w_data_o),
        
        .ext_mem_r_en_o  (wtb_mem_r_en_o),
        .ext_mem_r_addr_o(wtb_mem_r_addr_o),
        .ext_mem_r_data_i(wtb_mem_r_data_o),
        
        .level_o(WTB_LEVEL),
        
        .r_data_o (wtb_data),
        .r_empty_o(WTB_EMPTY),
        .r_en_i   (wtb_read),
        
        .w_data_i({fe_iob_addr_i, fe_iob_wdata_i, fe_iob_wstrb_i}),
        .w_full_o(WTB_FULL),
        .w_en_i  ((WRITE_POLICY == `IOB_CACHE_WRITE_THROUGH) & fe_iob_avalid_i & |fe_iob_wstrb_i & ~WTB_FULL)
        );
      );
   
   
  //Back-end interface
  iob_cache_back_end #(
      .ADDR_W    (NLINES_W),
      .DATA_W    (2**ADDR_OFFSET*DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W)
  ) back_end (
    `include "int_iob_portmap.vs"
    `include "be_iob_s_portmap.vs"
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
