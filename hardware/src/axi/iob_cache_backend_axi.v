`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"
`include "iob_cache_conf.vh"

module iob_cache_backend_axi #(
   parameter                ADDR_W     = 32,
   parameter                DATA_W     = 32,
   parameter                BE_ADDR_W     = 32,
   parameter                BE_DATA_W     = 32,
   parameter                WORD_OFFSET_W = 2,
   parameter                WRITE_POL     = 1,
   parameter                AXI_ID_W      = 0,
   parameter [AXI_ID_W-1:0] AXI_ID        = 0,
   parameter                AXI_LEN_W     = 0,
   parameter                AXI_ADDR_W    = BE_ADDR_W,
   parameter                AXI_DATA_W    = BE_DATA_W
) (
   //TODO: add the port stubs instead of the following lists
   // internal data interface
   output                      int_iob_avalid_o,
   output [ INT_ADDR_W-1:0]    int_iob_addr_o,
   output [ INT_DATA_W-1:0]    int_iob_wdata_o,
   output [(INT_DATA_W/8)-1:0] int_iob_wstrb_o,
   input                       int_iob_rvalid_i,
   input [ INT_DATA_W-1:0]     int_iob_rdata_i,
   input                       int_iob_ready_i,
   // back-end memory master interface
`include "iob_axi_m_port.vs"
   //clock and reset
`include "iob_clkenrst_port.vs"
   );
   

endmodule
