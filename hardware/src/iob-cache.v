`timescale 1ns / 1ps
`include "iob_lib.vh"
`include "iob-cache.vh"

///////////////
// IOb-cache //
///////////////

module iob_cache 
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
    //Replacement policy when N_WAYS > 1
    parameter REP_POLICY = `PLRU_mru, //PARAM & 0 & 3 & Line replacement policy: Least Recently Used (LRU, 0); Pseudo LRU (PLRU) based on Most Recently Used (PLRU_mru, 1); Tree-base PLRU (3)

    //Write Policy 
    parameter WRITE_POL = `WRITE_THROUGH, //PARAM & 0 & 1 & Write policy: write-through (0), write-back (1)
    /*---------------------------------------------------*/
    //Controller's options
    parameter CTRL_CACHE = 0, //PARAM & 0 & 1 & Instantiates a cache controller (1) or not (0). If the controller is present, all cache lines can be invalidated and the write through buffer empty status can be read
    parameter CTRL_CNT = 0, //PARAM & 0 & 1 & If CTRL_CACHE=1 and CTRL_CNT=1 , the cache will include software accessible hit/miss counters

    //Derived parameters DO NOT CHANGE
    parameter FE_NBYTES = FE_DATA_W/8,
    parameter FE_NBYTES_W = $clog2(FE_NBYTES),
    parameter BE_NBYTES = BE_DATA_W/8,
    parameter BE_NBYTES_W = $clog2(BE_NBYTES),
    //Cache-Memory base Offset
    parameter LINE2BE_W = WORD_OFFSET_W-$clog2(BE_DATA_W/FE_DATA_W) //line over back-end number of words ratio (log2)

    ) 
   (
    //START_IO_TABLE gen
    `IOB_INPUT(clk,1),   //System clock
    `IOB_INPUT(reset,1), //System reset, asynchronous and active high

    //Master i/f
    //START_IO_TABLE iob_m
    `IOB_INPUT(req, 1),          //Read or write request from CPU or other user core.
    `IOB_INPUT(addr,CTRL_CACHE + FE_ADDR_W), //Address from CPU or other user core.
    `IOB_INPUT(wdata,FE_DATA_W),   //Write data
    `IOB_INPUT(wstrb,FE_NBYTES),   //Native CPU interface write strobe signal
    `IOB_OUTPUT(rdata, FE_DATA_W), //Native CPU interface read data signal
    `IOB_OUTPUT(ack,1),          //Native CPU interface ack signal

    //Slave i/f - Native
    //START_IO_TABLE iob_s
    `IOB_OUTPUT(mem_req,1),         //Native CPU interface req signal
    `IOB_OUTPUT(mem_addr,BE_ADDR_W),  //Native CPU interface address signal
    `IOB_OUTPUT(mem_wdata,BE_DATA_W), //Native CPU interface data write signal
    `IOB_OUTPUT(mem_wstrb,BE_NBYTES), //Native CPU interface write strobe signal
    `IOB_INPUT(mem_rdata,BE_DATA_W),  //Native CPU interface read data signal
    `IOB_INPUT(mem_ack,1)           //Native CPU interface ack signal
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
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),
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

   //BLOCK Back-end & Back-end block.
   
   back_end_native
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),  
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WORD_OFFSET_W (WORD_OFFSET_W),
       .WRITE_POL (WRITE_POL)
       )
   back_end
     (
      .clk(clk),
      .reset(reset),
      //write-through-buffer (write-channel)
      .write_req (write_req),
      .write_addr  (write_addr),
      .write_wdata (write_wdata),
      .write_wstrb (write_wstrb),
      .write_ack (write_ack),
      //cache-line replacement (read-channel)
      .replace_req (replace_req),
      .replace_addr  (replace_addr),
      .replace (replace),
      .read_req (read_req),
      .read_addr  (read_addr),
      .read_rdata (read_rdata),
      //back-end native interface
      .mem_req (mem_req),
      .mem_addr  (mem_addr),
      .mem_wdata (mem_wdata),
      .mem_wstrb (mem_wstrb),
      .mem_rdata (mem_rdata),
      .mem_ack (mem_ack)  
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
         .req (ctrl_req),
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
         .ack (ctrl_ack),
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
