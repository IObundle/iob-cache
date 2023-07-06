`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_axi
   #(
`include "iob_cache_params.vs"
    ) 
   (
`include "iob_cache_io.vs"
    );

   //Cache memory & This block implements the cache memory.
   wire write_hit, write_miss, read_hit, read_miss;

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
  ) 
   dmem 
     (
      .clk_i         (clk_i),
      .arst_i        (arst_i),
      
      // front-end interface
`include "fe_iob_s_s_portmap.vs"

      // internal interface
`include "int_iob_m_portmap.vs"

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

   //Back-end interface & This block interfaces with the system level or next-level cache.
   iob_cache_backend_axi #(
      .ADDR_W       (ADDR_W),
      .DATA_W       (DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W),
   ) back_end (
     `include "int_iob_s_portmap.vs"
    `include "iob_axi_m_m_portmap.vs"
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
