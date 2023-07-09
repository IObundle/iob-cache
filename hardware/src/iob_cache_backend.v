`timescale 1ns / 1ps

`include "iob_cache_conf.vh"

module iob_cache_backend #(
   parameter BUF_ADDR_W     = 32,
   parameter BUF_DATA_W     = 32,
   parameter BUF_NBYTES = BUF_DATA_W/8,
   parameter BE_ADDR_W     = 32,
   parameter BE_DATA_W     = 32,
   parameter NWORDS_W = 2,
   parameter WRITE_POL     = 0,
   parameter WTB_DEPTH_W = 32
) (
   //TODO: add the port stubs instead of the following lists
   // internal data interface
   output wtb_mem_w_en_o,
   output [BUF_ADDR_W-1:0] wtb_mem_w_addr_o,
   output [BUF_DATA_W-1:0] wtb_mem_w_data_o,

   output wtb_mem_r_en_o,
   output [BUF_ADDR_W-1:0] wtb_mem_r_addr_o,
   input  [BUF_DATA_W-1:0] wtb_mem_r_data_i,
   
`include "buf_iob_s_port.vs"
   // back-end memory interface
`include "be_iob_m_port.vs"
   // clock and reset
`include "iob_clkenrst_port.vs"
   );

    generate
      if (WRITE_POL == "WRITE_THROUGH") begin: g_write_through

         wire [BUF_ADDR_W+BUF_DATA_W+BUF_NBYTES-1:0] wtb_wdata = {buf_iob_addr_i, buf_iob_wdata_i, buf_iob_wstrb_i};
         wire [BUF_ADDR_W+BUF_DATA_W+BUF_NBYTES-1:0] wtb_rdata;
         wire                                        wtb_wen = buf_iob_avalid_i & buf_iob_wstrb_i;
         wire                                        wtb_ren;
         
         //Write through buffer
         iob_fifo_sync 
           #(
             .R_DATA_W(BUF_ADDR_W+DATA_W+NBYTES),
             .W_DATA_W(BUF_ADDR_W+DATA_W+NBYTES),
             .ADDR_W  (WTB_DEPTH_W),
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

       localparam R = BUF_DATA_W/BE_DATA_W;
       localparam R_W = $clog2(R);

       wire [BE_ADDR_W-1:0] shiftv = wtb_rdata[BUF_DATA_W+BUF_NBYTES +: R_W];

       assign be_iob_addr_o = wtb_rdata[BUF_DATA_W+BUF_NBYTES+R_W +: BE_ADDR_W];
       assign be_iob_data_o = wtb_rdata[BUF_NBYTES +: BUF_DATA_W] << (shiftv*BUF_DATA_W);
       assign be_iob_wstrb_o = wtb_rdata[0 +: BUF_NBYTES] << (shiftv*BUF_NBYTES);

   endgenerate // generate
   

endmodule
