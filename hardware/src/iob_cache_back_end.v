`timescale 1ns / 1ps

`include "iob_cache.vh"

module iob_cache_back_end
  #(
    parameter ADDR_W   = `ADDR_W,
    parameter DATA_W   = `DATA_W,
    parameter BE_ADDR_W = `BE_ADDR_W,
    parameter BE_DATA_W = `BE_DATA_W,
    parameter WORD_OFFSET_W = `WORD_OFFSET_W,
    parameter WRITE_POL = `WRITE_THROUGH
    )
   (
    input                                                                       clk,
    input                                                                       reset,

    // write-through-buffer
    input                                                                       write_valid,
    input [ADDR_W-1 : `NBYTES_W + WRITE_POL*WORD_OFFSET_W]                     write_addr,
    input [DATA_W + WRITE_POL*(DATA_W*(2**WORD_OFFSET_W)-DATA_W)-1 :0] write_wdata,
    input [`NBYTES-1:0]                                                       write_wstrb,
    output                                                                      write_ready,

    // cache-line replacement
    input                                                                       replace_valid,
    input [ADDR_W -1: `NBYTES_W + WORD_OFFSET_W]                             replace_addr,
    output                                                                      replace,
    output                                                                      read_valid,
    output [`LINE2BE_W -1:0]                                                     read_addr,
    output [BE_DATA_W -1:0]                                                     read_rdata,

    // back-end memory interface
    output                                                                      mem_valid,
    output [BE_ADDR_W -1:0]                                                     mem_addr,
    output [BE_DATA_W-1:0]                                                      mem_wdata,
    output [`BE_NBYTES-1:0]                                                    mem_wstrb,
    input [BE_DATA_W-1:0]                                                       mem_rdata,
    input                                                                       mem_ready
    );

   wire [BE_ADDR_W-1:0]                                                         mem_addr_read,  mem_addr_write;
   wire                                                                         mem_valid_read, mem_valid_write;

   assign mem_addr  = (mem_valid_read)? mem_addr_read : mem_addr_write;
   assign mem_valid = mem_valid_read | mem_valid_write;

   iob_cache_read_channel
     #(
       .ADDR_W(ADDR_W),
       .DATA_W(DATA_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WORD_OFFSET_W (WORD_OFFSET_W)
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

   iob_cache_write_channel
     #(
       .ADDR_W (ADDR_W),
       .DATA_W (DATA_W),
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

endmodule
