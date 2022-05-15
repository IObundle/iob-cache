`timescale 1ns / 1ps
`include "iob_lib.vh"
`include "iob-cache.vh"

///////////////
// IOb-cache //
///////////////

module iob_cache_axi
  #(
    //memory cache's parameters
    parameter FE_ADDR_W = 32, //PARAM &  NS & NS & Front-end address width
    parameter FE_DATA_W = 32, //PARAM & 32 & 64 & Front-end data width
    parameter BE_ADDR_W = 32, //PARAM &  NS & NS & Back-end address width
    parameter BE_DATA_W = 32, //PARAM & 32 & 256 & Back-end data width
    parameter NWAYS_W = 1, //PARAM & ? 0 3 & Number of ways (log2)
    parameter LINE_OFFSET_W = 7, //PARAM & NS & NS & Line offset width: 2**LINE_OFFSET_W is the number of cache lines
    parameter WORD_OFFSET_W = 3, //PARAM & 0 & NS & Word offset width: 2**OFFSET_W is the number of words per line
    parameter WTBUF_DEPTH_W = 5, //PARAM & NS & NS & Write-through buffer depth (log2)
    //Replacement policy when NWAYS > 1
    parameter REP_POLICY = `PLRU_MRU, //PARAM & 0 & 3 & Line replacement policy. Set to 0 for Least Recently Used (LRU); set to 1 for Pseudo LRU based on Most Recently Used (PLRU_MRU); set to 2 for Tree-base Pseudo LRU (PLRU_TREE)

    //Write Policy 
    parameter WRITE_POL = `WRITE_THROUGH, //PARAM & 0 & 1 & Write policy: set to 0 for write-through or set to 1 for write-back
    /*---------------------------------------------------*/
    //Controller's options
    parameter CTRL_CACHE = 0, //PARAM & 0 & 1 & Instantiates a cache controller (1) or not (0). If the controller is present, all cache lines can be invalidated and the write through buffer empty status can be read
    parameter CTRL_CNT = 0, //PARAM & 0 & 1 & If CTRL_CACHE=1 and CTRL_CNT=1 , the cache will include software accessible hit/miss counters

    //Derived parameters DO NOT CHANGE
    parameter FE_NBYTES = FE_DATA_W/8,
    parameter FE_NBYTES_W = $clog2(FE_NBYTES),
    parameter BE_NBYTES = BE_DATA_W/8,
    parameter BE_NBYTES_W = $clog2(BE_NBYTES),
    parameter LINE2BE_W = WORD_OFFSET_W-$clog2(BE_DATA_W/FE_DATA_W), //line over back-end number of words ratio (log2)

    //AXI specific parameters
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0 //AXI ID value
    ) 
   (
    //START_IO_TABLE gen
    `IOB_INPUT(clk,1),   //System clock
    `IOB_INPUT(reset,1), //System reset, asynchronous and active high

    //Front-end interface (IOb native slave)
    //START_IO_TABLE fe_if
    `IOB_INPUT(req, 1), //Read or write request from CPU or other user core. If {\tt ack} becomes high in the next cyle the request has been served; otherwise {\tt req} should remain high until {\tt ack} returns to high. When {\tt ack} becomes high in reponse to a previous request, {\tt req} may be lowered in the same cycle ack becomes high if there are no more requests to make. The next request can be made while {\tt ack} is high in reponse to the previous request
    `IOB_INPUT(addr, CTRL_CACHE+FE_ADDR_W-FE_NBYTES_W), //Address from CPU or other user core, excluding the byte selection LSBs.
    `IOB_INPUT(wdata,FE_DATA_W), //Write data
    `IOB_INPUT(wstrb,FE_NBYTES), //Byte write strobe
    `IOB_OUTPUT(rdata, FE_DATA_W), //Read data
    `IOB_OUTPUT(ack,1), //Acknowledges that the last request has been served; the next request can be issued when this signal is high or when this signla is low but has already pulsed high in response to the last request.

    //Back-end interface (AXI4 master)
    //START_IO_TABLE be_if
    //Address Read
    output                                      axi_arvalid, 
    output [BE_ADDR_W-1:0]                      axi_araddr, 
    output [7:0]                                axi_arlen,
    output [2:0]                                axi_arsize,
    output [1:0]                                axi_arburst,
    output [0:0]                                axi_arlock,
    output [3:0]                                axi_arcache,
    output [2:0]                                axi_arprot,
    output [3:0]                                axi_arqos,
    output [AXI_ID_W-1:0]                       axi_arid,
    input                                       axi_arready,
    //Read
    input                                       axi_rvalid, 
    input [BE_DATA_W-1:0]                       axi_rdata,
    input [1:0]                                 axi_rresp,
    input                                       axi_rlast, 
    output                                      axi_rready,
    // Address Write
    output                                      axi_awvalid,
    output [BE_ADDR_W-1:0]                      axi_awaddr,
    output [7:0]                                axi_awlen,
    output [2:0]                                axi_awsize,
    output [1:0]                                axi_awburst,
    output [0:0]                                axi_awlock,
    output [3:0]                                axi_awcache,
    output [2:0]                                axi_awprot,
    output [3:0]                                axi_awqos,
    output [AXI_ID_W-1:0]                       axi_awid, 
    input                                       axi_awready,
    //Write
    output                                      axi_wvalid, 
    output [BE_DATA_W-1:0]                      axi_wdata,
    output [BE_NBYTES-1:0]                      axi_wstrb,
    output                                      axi_wlast,
    input                                       axi_wready,
    input                                       axi_bvalid,
    input [1:0]                                 axi_bresp,
    output                                      axi_bready
    );

   //BLOCK Front-end & Front-end interface.
   wire                              data_req, data_ack;
   wire [FE_ADDR_W -1:FE_NBYTES_W]   data_addr; 
   wire [FE_DATA_W-1 : 0]            data_wdata, data_rdata;
   wire [FE_NBYTES-1: 0]             data_wstrb;
   wire [FE_ADDR_W -1:FE_NBYTES_W]   data_addr_reg; 
   wire [FE_DATA_W-1 : 0]            data_wdata_reg;
   wire [FE_NBYTES-1: 0]             data_wstrb_reg;
   wire                              data_req_reg;

   wire                              ctrl_req, ctrl_ack;   
   wire [`CTRL_ADDR_W-1:0]           ctrl_addr;
   wire [CTRL_CACHE*(FE_DATA_W-1):0] ctrl_rdata;

   front_end
     #(
       .ADDR_W (FE_ADDR_W-FE_NBYTES_W),
       .DATA_W (FE_DATA_W),
       .CTRL_CACHE(CTRL_CACHE)
       )
   front_end
     (
      .clk   (clk),
      .reset (reset),
      //front-end port
      .req (req),
      .addr  (addr),
      .wdata (wdata),
      .wstrb (wstrb),
      .rdata (rdata),
      .ack (ack),
      //cache-memory input signals
      .data_req (data_req),
      .data_addr  (data_addr),
      //cache-memory output
      .data_rdata (data_rdata),
      .data_ack (data_ack),
      //stored input signals
      .data_req_reg (data_req_reg),
      .data_addr_reg  (data_addr_reg),
      .data_wdata_reg (data_wdata_reg),
      .data_wstrb_reg (data_wstrb_reg),
      //cache-controller
      .ctrl_req (ctrl_req),
      .ctrl_addr  (ctrl_addr),
      .ctrl_rdata (ctrl_rdata),
      .ctrl_ack (ctrl_ack)
      );


   //BLOCK Cache memory & This block implements the cache memory.
   wire                              wtbuf_full, wtbuf_empty;
   wire                              write_hit, write_miss, read_hit, read_miss;
   wire                              invalidate;   

   //back-end write-channel
   wire                              write_req, write_ack;
   wire [FE_ADDR_W-1:FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr;
   wire [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 :0] write_wdata;
   wire [FE_NBYTES-1:0]                                                       write_wstrb;
   //back-end read-channel
   wire                                                                       replace_req, replace;
   wire [FE_ADDR_W -1:BE_NBYTES_W+LINE2BE_W]                                  replace_addr; 
   wire                                                                       read_req;
   wire [LINE2BE_W-1:0]                                                       read_addr;
   wire [BE_DATA_W-1:0]                                                       read_rdata;
   
   cache_memory
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),
       .BE_DATA_W (BE_DATA_W),
       .NWAYS_W (NWAYS_W),
       .LINE_OFFSET_W (LINE_OFFSET_W),
       .WORD_OFFSET_W (WORD_OFFSET_W),
       .REP_POLICY (REP_POLICY),    
       .WTBUF_DEPTH_W (WTBUF_DEPTH_W),
       .CTRL_CACHE(CTRL_CACHE),
       .CTRL_CNT (CTRL_CNT),
       .WRITE_POL (WRITE_POL)
       )
   cache_memory
     (
      .clk   (clk),
      .reset (reset),

      //front-end
      .req (data_req),
      .addr (data_addr[FE_ADDR_W-1 : BE_NBYTES_W+LINE2BE_W]),
      .rdata (data_rdata),
      .ack (data_ack),
      .req_reg (data_req_reg),   
      .addr_reg (data_addr_reg),
      .wdata_reg (data_wdata_reg),
      .wstrb_reg (data_wstrb_reg),

      //back-end
      //write-through-buffer (write-channel)
      .write_req (write_req),
      .write_addr (write_addr),
      .write_wdata (write_wdata),
      .write_wstrb (write_wstrb),
      .write_ack (write_ack),
      //cache-line replacement (read-channel)
      .replace_req (replace_req),
      .replace_addr (replace_addr),
      .replace (replace),
      .read_req (read_req),
      .read_addr (read_addr),
      .read_rdata (read_rdata),
      //control's signals 
      .wtbuf_empty (wtbuf_empty),
      .wtbuf_full (wtbuf_full),
      .write_hit (write_hit),
      .write_miss (write_miss),
      .read_hit (read_hit),
      .read_miss (read_miss),
      .invalidate (invalidate)
      );

   //BLOCK Back-end interface & This block interfaces with the system level or next-level cache.

   back_end_axi
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),  
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WORD_OFFSET_W(WORD_OFFSET_W),
       .WRITE_POL (WRITE_POL),
       .AXI_ID_W(AXI_ID_W),
       .AXI_ID(AXI_ID)
       )
   back_end
     (
      .clk(clk),
      .reset(reset),
      //write-through-buffer (write-channel)
      .write_valid (write_req),
      .write_addr (write_addr),
      .write_wdata (write_wdata),
      .write_wstrb (write_wstrb),
      .write_ready (write_ack),
      //cache-line replacement (read-channel)
      .replace_valid (replace_req),
      .replace_addr (replace_addr),
      .replace (replace),
      .read_valid (read_req),
      .read_addr (read_addr),
      .read_rdata (read_rdata),
      //back-end read-channel
      //read address
      .axi_arvalid (axi_arvalid), 
      .axi_araddr (axi_araddr), 
      .axi_arlen (axi_arlen),
      .axi_arsize (axi_arsize),
      .axi_arburst (axi_arburst),
      .axi_arlock (axi_arlock),
      .axi_arcache (axi_arcache),
      .axi_arprot (axi_arprot),
      .axi_arqos (axi_arqos),
      .axi_arid (axi_arid),
      .axi_arready (axi_arready),
      //read data
      .axi_rvalid (axi_rvalid), 
      .axi_rdata (axi_rdata),
      .axi_rresp (axi_rresp),
      .axi_rlast (axi_rlast), 
      .axi_rready (axi_rready),
      //back-end write-channel
      //write address
      .axi_awvalid (axi_awvalid), 
      .axi_awaddr (axi_awaddr), 
      .axi_awlen (axi_awlen),
      .axi_awsize (axi_awsize),
      .axi_awburst (axi_awburst),
      .axi_awlock (axi_awlock),
      .axi_awcache (axi_awcache),
      .axi_awprot (axi_awprot),
      .axi_awqos (axi_awqos),
      .axi_awid (axi_awid),
      .axi_awready (axi_awready),
      //write data
      .axi_wvalid (axi_wvalid),
      .axi_wdata (axi_wdata),
      .axi_wstrb (axi_wstrb),
      .axi_wready (axi_wready),
      .axi_wlast (axi_wlast),
      //write response
      .axi_bvalid (axi_bvalid), 
      .axi_bresp (axi_bresp),
      .axi_bready (axi_bready) 
      );
   
   //BLOCK Cache control & Cache control block.
   generate
      if (CTRL_CACHE)
         
        cache_control
          #(
            .FE_DATA_W  (FE_DATA_W),
            .CTRL_CNT   (CTRL_CNT)
            )
      cache_control
        (
         .clk (clk),
         .reset (reset),
         //control's signals
         .valid (ctrl_req),
         .addr (ctrl_addr),
         //write data
         .wtbuf_full (wtbuf_full),
         .wtbuf_empty (wtbuf_empty), 
         .write_hit (write_hit),
         .write_miss (write_miss),
         .read_hit (read_hit),
         .read_miss (read_miss),
         ////////////
         .rdata (ctrl_rdata),
         .ready (ctrl_ack),
         .invalidate (invalidate)
         );
      else
        begin
           assign ctrl_rdata = 1'bx;
           assign ctrl_ack = 1'bx;
           assign invalidate = 1'b0;
        end
      
   endgenerate

endmodule // iob_cache   
