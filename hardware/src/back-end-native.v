`timescale 1ns / 1ps
`include "iob-cache.vh"

module back_end_native
  #(
    //memory cache's parameters
    parameter FE_ADDR_W   = 32,
    parameter FE_DATA_W   = 32,
    parameter WORD_OFFSET_W = 3,
    parameter BE_ADDR_W = FE_ADDR_W,
    parameter BE_DATA_W = FE_DATA_W,

    //Derived parameters DO NOT CHANGE
    parameter FE_NBYTES  = FE_DATA_W/8,
    parameter FE_BYTE_W  = $clog2(FE_NBYTES), //Byte Offset
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 

    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTE_W = $clog2(BE_NBYTES), //Offset of Number of Bytes
    //Cache-Memory base Offset
    parameter LINE2MEM_W = WORD_OFFSET_W-$clog2(BE_DATA_W/FE_DATA_W),
    // Write-Policy
    parameter WRITE_POL = `WRITE_THROUGH //write policy: write-through (0), write-back (1)
    ) 
   (
    input                                                                       clk,
    input                                                                       reset,
    //write-through-buffer
    input                                                                       write_valid,
    input [FE_ADDR_W-1:FE_BYTE_W + WRITE_POL*WORD_OFFSET_W]                     write_addr,
    input [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 :0] write_wdata,
    input [FE_NBYTES-1:0]                                                       write_wstrb,
    output                                                                      write_ready,
    //cache-line replacement
    input                                                                       replace_valid,
    input [FE_ADDR_W -1: FE_BYTE_W + WORD_OFFSET_W]                             replace_addr,
    output                                                                      replace,
    output                                                                      read_valid,
    output [LINE2MEM_W -1:0]                                                    read_addr,
    output [BE_DATA_W -1:0]                                                     read_rdata,
    //back-end memory interface
    output                                                                      mem_valid,
    output [BE_ADDR_W -1:0]                                                     mem_addr,
    output [BE_DATA_W-1:0]                                                      mem_wdata,
    output [BE_NBYTES-1:0]                                                      mem_wstrb,
    input [BE_DATA_W-1:0]                                                       mem_rdata,
    input                                                                       mem_ready
    );

   wire [BE_ADDR_W-1:0]                                                      mem_addr_read,  mem_addr_write;
   wire                                                                      mem_valid_read, mem_valid_write;

   assign mem_addr =  (mem_valid_read)? mem_addr_read : mem_addr_write;
   assign mem_valid = mem_valid_read | mem_valid_write;                   
   
   
   read_channel_native
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),  
       .WORD_OFFSET_W(WORD_OFFSET_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W)
       )
   read_fsm
     (
      .clk(clk),
      .reset(reset),
      .replace_valid (replace_valid),
      .replace_addr (replace_addr),
      .replace (replace),
      .read_valid (read_valid),
      .read_addr (read_addr),
      .read_rdata (read_rdata),
      .mem_addr(mem_addr_read),
      .mem_valid(mem_valid_read),
      .mem_ready(mem_ready),
      .mem_rdata(mem_rdata)  
      );

   write_channel_native
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WRITE_POL (WRITE_POL),
       .WORD_OFFSET_W(WORD_OFFSET_W)
       )
   write_fsm
     (
      .clk(clk),
      .reset(reset),
      .valid (write_valid),
      .addr (write_addr),
      .wstrb (write_wstrb),
      .wdata (write_wdata),
      .ready (write_ready),
      .mem_addr(mem_addr_write),
      .mem_valid(mem_valid_write),
      .mem_ready(mem_ready),
      .mem_wdata(mem_wdata),
      .mem_wstrb(mem_wstrb)
      );
   
endmodule // back_end_native
