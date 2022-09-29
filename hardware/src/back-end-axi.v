`timescale 1ns / 1ps
`include "iob_lib.vh"
`include "iob-cache.vh"

module back_end_axi
  #(
    //memory cache's parameters
    parameter FE_ADDR_W   = 32,       //Address width - width of the Master's entire access address (including the LSBs that are discarded, but discarding the Controller's)
    parameter FE_DATA_W   = 32,       //Data width - word size used for the cache
    parameter WORD_OFF_W = 3,      //Word-Offset Width - 2**OFFSET_W total FE_DATA_W words per line - WARNING about LINE2MEM_W (can cause word_counter [-1:0]
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory

    parameter FE_NBYTES  = FE_DATA_W/8,        //Number of Bytes per Word
    parameter FE_BYTE_W  = $clog2(FE_NBYTES), //Byte Offset
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 

    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTE_W = $clog2(BE_NBYTES), //Offset of Number of Bytes
    //Cache-Memory base Offset
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W),
    // Write-Policy
    parameter WRITE_POL = `WRITE_THROUGH, //write policy: write-through (0), write-back (1)
    //AXI specific parameters
    parameter AXI_ADDR_W            = BE_ADDR_W,
    parameter AXI_DATA_W            = BE_DATA_W,
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter AXI_LEN_W             = 8, //AXI ID burst length (log2)
    parameter [AXI_ID_W-1:0] AXI_ID = 0  //AXI ID value
    ) 
   (
    //write-through-buffer
    input                                                                    write_valid,
    input [FE_ADDR_W-1:FE_BYTE_W + WRITE_POL*WORD_OFF_W]                     write_addr,
    input [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFF_W)-FE_DATA_W)-1 :0] write_wdata,
    input [FE_NBYTES-1:0]                                                    write_wstrb,
    output                                                                   write_ready,
    //cache-line replacement
    input                                                                    replace_valid,
    input [FE_ADDR_W -1: FE_BYTE_W + WORD_OFF_W]                             replace_addr,
    output                                                                   replace,
    output                                                                   read_valid,
    output [LINE2MEM_W -1:0]                                                 read_addr,
    output [BE_DATA_W -1:0]                                                  read_rdata,

    //AXI master backend interface
`include "m_axi_m_port.vh"
    input                                                                    clk,
    input                                                                    reset
    );


   
   read_channel_axi
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),  
       .WORD_OFF_W(WORD_OFF_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .AXI_ADDR_W(AXI_ADDR_W),
       .AXI_DATA_W(AXI_DATA_W),
       .AXI_ID_W(AXI_ID_W),
       .AXI_LEN_W(AXI_LEN_W),
       .AXI_ID  (AXI_ID)
       )
   read_fsm
     (
      .replace_valid (replace_valid),
      .replace_addr (replace_addr),
      .replace (replace),
      .read_valid (read_valid),
      .read_addr (read_addr),
      .read_rdata (read_rdata),
      `include "m_axi_read_portmap.vh"
      .clk(clk),
      .reset(reset)
      );

   
   write_channel_axi
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WRITE_POL (WRITE_POL),
       .WORD_OFF_W(WORD_OFF_W),
       .AXI_ADDR_W(AXI_ADDR_W),
       .AXI_DATA_W(AXI_DATA_W),
       .AXI_LEN_W(AXI_LEN_W),
       .AXI_ID_W(AXI_ID_W),
       .AXI_ID(AXI_ID)
       )
   write_fsm
     (
      .valid (write_valid),
      .addr (write_addr),
      .wstrb (write_wstrb),
      .wdata (write_wdata),
      .ready (write_ready),
      `include "m_axi_write_portmap.vh"
      .clk(clk),
      .reset(reset)
      );
   
endmodule // back_end_native
