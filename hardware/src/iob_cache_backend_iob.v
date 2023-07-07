`timescale 1ns / 1ps

`include "iob_cache_conf.vh"

module iob_cache_backend_iob #(
   parameter ADDR_W     = 32,
   parameter DATA_W     = 32,
   parameter BE_ADDR_W     = 32,
   parameter BE_DATA_W     = 32,
   parameter WORD_OFFSET_W = 2,
   parameter WRITE_POL     = 0
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
   // back-end memory interface
   output                      be_iob_avalid_o,
   output [ BE_ADDR_W-1:0]     be_iob_addr_o,
   output [ BE_DATA_W-1:0]     be_iob_wdata_o,
   output [(BE_DATA_W/8)-1:0]  be_iob_wstrb_o,
   input                       be_iob_rvalid_i,
   input [ BE_DATA_W-1:0]      be_iob_rdata_i,
   input                       be_iob_ready_i,
`include "iob_clkenrst_port.vs"
   );

   wire be_valid_read, be_valid_write;
   assign be_iob_avalid_o = be_valid_read | be_valid_write;

   wire [BE_ADDR_W-1:0] be_addr_read, be_addr_write;
   assign be_iob_addr_o  = (be_valid_read) ? be_addr_read : be_addr_write;

endmodule
