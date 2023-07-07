`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_iob 
  #(
`include "iob_cache_params.vs"
    ) 
   (
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

   wire write_hit;
   wire write_miss;
   wire read_hit;
   wire read_miss;
   
   iob_cache_dmem #(
      .ADDR_W        (ADDR_W),
      .DATA_W        (DATA_W),
      .NWAYS_W       (NWAYS_W),
      .NLINES_W      (NLINES_W),
      .WORD_OFFSET_W (WORD_OFFSET_W),
      .REPLACE_POL   (REPLACE_POL),
      .WRITE_POL     (WRITE_POL)
  ) 
   dmem 
     (
      .clk_i         (clk_i),
      .arst_i        (arst_i),
      
      // front-end interface
`include "fe_iob_s_s_portmap.vs"

      // internal interface
`include "int_iob_m_portmap.vs"

      .data_mem_en_o (data_mem_en_o),
      .data_mem_en_o (data_mem_we_o),
      .data_mem_addr_o(data_mem_addr_o),
      .data_mem_d_o(data_mem_d_o),
      .data_mem_d_i(data_mem_d_i),

    
      // control and status signals
      .invalidate_i    (INVALIDATE),
      .write_hit_o     (write_hit),
      .write_miss_o    (write_miss),
      .read_hit_o      (read_hit),
      .read_miss_o     (read_miss)
  );

   generate
      if (WRITE_POL == "WRITE_THROUGH") begin: g_write_through

         wire [FE_ADDR_W+DATA_W+NBYTES-1:0] wtb_wdata = {fe_iob_addr_i, fe_iob_wdata_i, fe_iob_wstrb_i};
         wire [FE_ADDR_W+DATA_W+NBYTES-1:0] wtb_rdata;
         wire                                  wtb_wen = fe_iob_avalid_i & fe_iob_wstrb_i;
         wire                                  wtb_ren;
         
         //Write through buffer
         iob_fifo_sync 
           #(
             .R_DATA_W(FE_ADDR_W+DATA_W+NBYTES),
             .W_DATA_W(FE_ADDR_W+DATA_W+NBYTES),
             .ADDR_W  (WTBUF_DEPTH_W)
             ) 
         write_throught_buffer 
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
            .ext_mem_r_data_i(wtb_mem_r_data_i),
            
            .w_data_i(wtb_wdata),
            .w_full_o(WTB_FULL),
            .w_en_i  (wtb_wen),

            .r_data_o (wtb_rdata),
            .r_empty_o(WTB_EMPTY),
            .r_en_i   (wtb_ren),
            
            .level_o(WTB_LEVEL)
            
            );
      end // block: g_write_through
   endgenerate // generate
   
  //Back-end interface
  iob_cache_backend_iob #(
      .ADDR_W       (NLINES_W),
      .DATA_W       ((2**WORD_OFFSET_W)*DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W)
  ) back_end (
    `include "int_iob_s_portmap.vs"
    `include "be_iob_m_m_portmap.vs"
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
