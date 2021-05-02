`timescale 1ns / 1ps
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
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0  //AXI ID value
    ) 
   (
    input                                                                    clk,
    input                                                                    reset,
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
    //Slave i/f -AXI
    //Address Read
    output                                                                   axi_arvalid, 
    output [BE_ADDR_W-1:0]                                                   axi_araddr, 
    output [7:0]                                                             axi_arlen,
    output [2:0]                                                             axi_arsize,
    output [1:0]                                                             axi_arburst,
    output [0:0]                                                             axi_arlock,
    output [3:0]                                                             axi_arcache,
    output [2:0]                                                             axi_arprot,
    output [3:0]                                                             axi_arqos,
    output [AXI_ID_W-1:0]                                                    axi_arid,
    input                                                                    axi_arready,
    //Read
    input                                                                    axi_rvalid, 
    input [BE_DATA_W-1:0]                                                    axi_rdata,
    input [1:0]                                                              axi_rresp,
    input                                                                    axi_rlast, 
    output                                                                   axi_rready,
    // Address Write
    output                                                                   axi_awvalid,
    output [BE_ADDR_W-1:0]                                                   axi_awaddr,
    output [7:0]                                                             axi_awlen,
    output [2:0]                                                             axi_awsize,
    output [1:0]                                                             axi_awburst,
    output [0:0]                                                             axi_awlock,
    output [3:0]                                                             axi_awcache,
    output [2:0]                                                             axi_awprot,
    output [3:0]                                                             axi_awqos,
    output [AXI_ID_W-1:0]                                                    axi_awid, 
    input                                                                    axi_awready,
    //Write
    output                                                                   axi_wvalid, 
    output [BE_DATA_W-1:0]                                                   axi_wdata,
    output [BE_NBYTES-1:0]                                                   axi_wstrb,
    output                                                                   axi_wlast,
    input                                                                    axi_wready,
    input                                                                    axi_bvalid,
    input [1:0]                                                              axi_bresp,
    output                                                                   axi_bready
    );


   
   read_channel_axi
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),  
       .WORD_OFF_W(WORD_OFF_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .AXI_ID_W(AXI_ID_W),
       .AXI_ID  (AXI_ID)
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
      //read address
      .axi_arvalid(axi_arvalid), 
      .axi_araddr(axi_araddr), 
      .axi_arlen(axi_arlen),
      .axi_arsize(axi_arsize),
      .axi_arburst(axi_arburst),
      .axi_arlock(axi_arlock),
      .axi_arcache(axi_arcache),
      .axi_arprot(axi_arprot),
      .axi_arqos(axi_arqos),
      .axi_arid(axi_arid),
      .axi_arready(axi_arready),
      //read data
      .axi_rvalid(axi_rvalid), 
      .axi_rdata(axi_rdata),
      .axi_rresp(axi_rresp),
      .axi_rlast(axi_rlast), 
      .axi_rready(axi_rready) 
      );

   
   write_channel_axi
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WRITE_POL (WRITE_POL),
       .WORD_OFF_W(WORD_OFF_W),
       .AXI_ID_W(AXI_ID_W),
       .AXI_ID(AXI_ID)
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
      //write address
      .axi_awvalid(axi_awvalid), 
      .axi_awaddr(axi_awaddr), 
      .axi_awlen(axi_awlen),
      .axi_awsize(axi_awsize),
      .axi_awburst(axi_awburst),
      .axi_awlock(axi_awlock),
      .axi_awcache(axi_awcache),
      .axi_awprot(axi_awprot),
      .axi_awqos(axi_awqos),
      .axi_awid(axi_awid),
      .axi_awready(axi_awready),
      //write data
      .axi_wvalid(axi_wvalid),
      .axi_wdata(axi_wdata),
      .axi_wstrb(axi_wstrb),
      .axi_wready(axi_wready),
      .axi_wlast(axi_wlast),
      //write response
      .axi_bvalid(axi_bvalid), 
      .axi_bresp(axi_bresp),
      .axi_bready(axi_bready) 
      );
   
endmodule // back_end_native
