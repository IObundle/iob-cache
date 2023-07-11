`timescale 1ns / 1ps

`include "iob_cache_conf.vh"

module iob_cache_backend #(
   parameter BE_ADDR_W     = 32,
   parameter BE_DATA_W     = 32,
   parameter BE_NBYTES = BE_DATA_W/8,
   parameter WRITE_POL     = 0,
   parameter WTB_DEPTH_W = 32,
   parameter WTB_DATA_W = BE_ADDR_W+BE_DATA_W+BE_NBYTES
) (
   
`include "buf_iob_s_port.vs"

   //TODO: add the port stubs instead of the following lists
   //external memory interface
   output wtb_mem_w_en_o,
   output [WTB_DEPTH_W-1:0] wtb_mem_w_addr_o,
   output [WTB_DATA_W-1:0] wtb_mem_w_data_o,

   output wtb_mem_r_en_o,
   output [WTB_DEPTH_W-1:0] wtb_mem_r_addr_o,
   input  [WTB_DATA_W-1:0] wtb_mem_r_data_i,

   //write buffer status
   output wtb_empty_o,
   output wtb_full_o,
   output [WTB_DEPTH_W-1:0] wtb_level_o,
   
   // back-end memory interface
`include "be_iob_m_port.vs"
   // clock and reset
`include "iob_clk_en_rst_port.vs"
   );

    generate
      if (WRITE_POL == "WRITE_THROUGH") begin: g_write_through

         wire [WTB_DATA_W-1:0] wtb_wdata = {buf_iob_addr_i, buf_iob_wdata_i, buf_iob_wstrb_i};
         wire [WTB_DATA_W-1:0] wtb_rdata;
         wire                  wtb_wen = buf_iob_avalid_i & buf_iob_wstrb_i;
         wire                  wtb_ren;
         
         //Write through buffer
         iob_fifo_sync 
           #(
             .R_DATA_W(BE_ADDR_W+DATA_W+NBYTES),
             .W_DATA_W(BE_ADDR_W+DATA_W+NBYTES),
             .ADDR_W  (WTB_DEPTH_W),
             ) 
         write_throught_buffer 
           (
            .clk_i (clk_i),
            .arst_i(arst_i),
            .cke_i (1'b1),
            .rst_i (arst_i),
            //write port
            .w_data_i(wtb_wdata),
            .w_full_o(wtb_full_o),
            .w_en_i  (wtb_wen),
            //read port
            .r_data_o (wtb_rdata),
            .r_empty_o(wtb_empty_o),
            .r_en_i   (wtb_ren),
            //status
            .level_o(wtb_level_o)
          
            //external memory interface
            .ext_mem_w_en_o  (wtb_mem_w_en_o),
            .ext_mem_w_addr_o(wtb_mem_w_addr_o),
            .ext_mem_w_data_o(wtb_mem_w_data_o),
            .ext_mem_r_en_o  (wtb_mem_r_en_o),
            .ext_mem_r_addr_o(wtb_mem_r_addr_o),
            .ext_mem_r_data_i(wtb_mem_r_data_i),
            );
      end // block: g_write_through

       assign be_iob_addr_o = wtb_rdata[BE_DATA_W+BE_NBYTES+R_W +: BE_ADDR_W];
       assign be_iob_data_o = wtb_rdata[BE_NBYTES +: BE_DATA_W];
       assign be_iob_wstrb_o = wtb_rdata[0 +: BE_NBYTES];

   endgenerate // generate
   

endmodule
