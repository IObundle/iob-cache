`timescale 1ns / 1ps
`include "iob-cache.vh"

///////////////
// IOb-cache //
///////////////

module iob_cache 
  #(
    //memory cache's parameters
    parameter FE_ADDR_W   = 32,       //Address width - width of the Master's entire access address (including the LSBs that are discarded, but discarding the Controller's)
    parameter FE_DATA_W   = 32,       //Data width - word size used for the cache
    parameter N_WAYS   = 4,        //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter LINE_OFF_W  = 6,     //Line-Offset Width - 2**NLINE_W total cache lines
    parameter WORD_OFF_W = 3,      //Word-Offset Width - 2**OFFSET_W total FE_DATA_W words per line - WARNING about LINE2MEM_DATA_RATIO_W (can cause word_counter [-1:0]
    parameter WTBUF_DEPTH_W = 4,   //Depth Width of Write-Through Buffer
    //Replacement policy (N_WAYS > 1)
    parameter REP_POLICY = `LRU, //LRU - Least Recently Used (0); BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    //Do NOT change - memory cache's parameters - dependency
    parameter NWAY_W   = $clog2(N_WAYS),  //Cache Ways Width
    parameter FE_NBYTES  = FE_DATA_W/8,        //Number of Bytes per Word
    parameter FE_BYTES_W  = $clog2(FE_NBYTES), //Byte Offset
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTES_W = $clog2(BE_NBYTES), //Offset of Number of Bytes
    //Cache-Memory base Offset
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W),//Logarithm Ratio between the size of the cache-line and the BE's data width 
    /*---------------------------------------------------*/
  
    //Controller's options
    parameter CTRL_CACHE = 0, //Adds a Controller to the cache, to use functions sent by the master or count the hits and misses
    parameter CTRL_CNT = 0  //Counters for Cache Hits and Misses - Disabling this and previous, the Controller only store the buffer states and allows cache invalidation
    ) 
   (
    input                                        clk,
    input                                        reset,
    //Master i/f
    input                                        valid,
`ifdef WORD_ADDR   
    input [CTRL_CACHE + FE_ADDR_W -1:FE_BYTES_W] addr, //MSB is used for Controller selection
`else
    input [CTRL_CACHE + FE_ADDR_W -1:0]          addr, //MSB is used for Controller selection
`endif
    input [FE_DATA_W-1:0]                        wdata,
    input [FE_NBYTES-1:0]                        wstrb,
    output [FE_DATA_W-1:0]                       rdata,
    output                                       ready,
    //Slave i/f - Native
    output                                       mem_valid,
    output [BE_ADDR_W-1:0]                       mem_addr,
    output [BE_DATA_W-1:0]                       mem_wdata,
    output [BE_NBYTES-1:0]                       mem_wstrb,
    input [BE_DATA_W-1:0]                        mem_rdata,
    input                                        mem_ready
    );

   
   //internal signals (front-end inputs)
   wire [FE_ADDR_W -1:FE_BYTES_W]                addr_int; 
   wire [FE_DATA_W-1 : 0]                        wdata_int;
   wire [FE_NBYTES-1: 0]                         wstrb_int;
   wire                                          valid_int;
   
   //stored signals
   wire [FE_ADDR_W -1:FE_BYTES_W]                addr_reg; 
   wire [FE_DATA_W-1 : 0]                        wdata_reg;
   wire [FE_NBYTES-1: 0]                         wstrb_reg;
   wire                                          valid_reg;
   
   //cache-memory
   wire                                          hit;
   // write-through buffer
   wire                                          buffer_full, buffer_empty; //cache_memory
   wire                                          buffer_idle, buffer_readen;//back-end
   
   //cache-line replacement
   wire                                          rep_init, rep_valid, rep_line;
   wire [BE_DATA_W-1:0]                          rep_rdata;
   wire [LINE2MEM_DATA_RATIO_W-1:0]              rep_counter;
   wire [FE_ADDR_W -1:BE_BYTES_W+LINE2MEM_W]     rep_addr; 
   
   //cache-control
   wire                                          ctrl_valid, ctrl_ready;   
   wire [`CTRL_ADDR_W-1:0]                       ctrl_addr;
   wire [`CTRL_COUNTER_W+1:0]                    ctrl_wdata;//{buffer_state[1:0], ctrl_counters}   
   wire [FE_DATA_W-1:0]                          ctrl_data;
   wire                                          invalidate;
   
   
   
   front_end
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W)
       )
   front_end
     (
      .clk   (clk),
      .reset (reset),
      //front-end port
      .valid (valid),
      .addr  (addr),
      .wdata (wdata),
      .wstrb (wstrb),
      .rdata (rdata),
      .ready (ready),
      //internal input signals
      .valid_int (valid_int),
      .addr_int  (addr_int),
      .wdata_int (wdata_int),
      .wstrb_int (wstrb_int),
      //cache-memory output
      .rdata_int (rdata_int),
      //stored input signals
      .valid_reg (valid_reg),
      .addr_reg  (addr_reg),
      .wdata_reg (wdata_reg),
      .wstrb_reg (wstrb_reg),
      //memory signals
      .hit         (hit),
      .buffer_full (buffer_full),
      //cache-control
      .ctrl_valid (ctrl_valid),
      .ctrl_addr  (ctrl_addr),
      .ctrl_rdata (ctrl_rdata),
      .ctrl_ready (ctrl_ready)
      );


   
   cache_memory
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),
       .BE_DATA_W (BE_DATA_W),
       .N_WAYS     (N_WAYS),
       .LINE_OFF_W (LINE_OFF_W),
       .WORD_OFF_W (WORD_OFF_W),
       .REP_POLICY (REP_POLICY),    
       .WTBUF_DEPTH_W (WTBUF_DEPTH_W)
       )
   cache_memory
     (
      .clk   (clk),
      .reset (reset),
      //front-end
      //internal
      .valid (valid_int),
      .addr  (addr_int),
      .wdata (wdata_int),
      .wstrb (wstrb_int),
      .rdata (rdata_int),
      //stored
      .valid_reg (valid_reg),   
      .addr_reg  (addr_reg),
      .wdata_reg (wdata_reg),
      .wstrb_reg (wstrb_reg),
      //cache-memory signals
      .hit       (hit), 
      //back-end
      //write-through-buffer (write-channel)
      .buffer_full   (buffer_full),
      .buffer_empty  (buffer_empty),
      .buffer_output (buffer_output),
      .buffer_readen (buffer_readen),
      .buffer_idle   (buffer_idle),
      //cache-line replacement (read-channel)
      .rep_init    (rep_init),
      .rep_addr    (rep_addr),
      .rep_rdata   (rep_rdata),
      .rep_valid   (rep_valid),
      .rep_line    (rep_line),
      .rep_counter (rep_counter),
      //control's signals
      .ctrl_wdata (ctrl_wdata),
      .invalidate (invalidate)
      );



   
   back_end_native
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),  
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WORD_OFF_W (WORD_OFF_W)
       )
   back_end
     (
      .clk(clk),
      .reset(reset),
      //write-through-buffer (write-channel)
      .buffer_full   (buffer_full),
      .buffer_empty  (buffer_empty),
      .buffer_output (buffer_output),
      .buffer_readen (buffer_readen),
      .buffer_idle   (buffer_idle),
      //cache-line replacement (read-channel)
      .rep_init    (rep_init),
      .rep_addr    (rep_addr),
      .rep_data    (rep_data),
      .rep_valid   (rep_valid),
      .rep_line    (rep_line),
      .rep_counter (rep_counter),
      //back-end native interface
      .mem_valid (mem_valid),
      .mem_addr (mem_addr),
      .mem_wdata (mem_wdata),
      .mem_wstrb (mem_wstrb),
      .mem_rdata (mem_rdata),
      .mem_ready (mem_ready)  
      );
   
   
   
   generate
      if (CTRL_CACHE)
         
        cache_control
          #(
            .FE_DATA_W  (FE_DATA_W),
            .CTRL_CNT   (CTRL_CNT)
            )
      cache_control
        (
         .clk   (clk),
         .reset (reset),
         //control's signals
         .ctrl_valid (ctrl_valid),
         .ctrl_addr  (ctrl_addr),
         .ctrl_wdata (ctrl_wdata),
         .ctrl_rdata (ctrl_rdata),
         .ctrl_ready (ctrl_ready),
         .invalidate (invalidate)
         );
      
   endgenerate

endmodule // iob_cache   


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


module iob_cache_axi 
  #(
    //memory cache's parameters
    parameter FE_ADDR_W   = 32,       //Address width - width of the Master's entire access address (including the LSBs that are discarded, but discarding the Controller's)
    parameter FE_DATA_W   = 32,       //Data width - word size used for the cache
    parameter N_WAYS   = 4,        //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter LINE_OFF_W  = 6,     //Line-Offset Width - 2**NLINE_W total cache lines
    parameter WORD_OFF_W = 3,      //Word-Offset Width - 2**OFFSET_W total FE_DATA_W words per line - WARNING about LINE2MEM_DATA_RATIO_W (can cause word_counter [-1:0]
    parameter WTBUF_DEPTH_W = 4,   //Depth Width of Write-Through Buffer
    //Replacement policy (N_WAYS > 1)
    parameter REP_POLICY = `LRU, //LRU - Least Recently Used (0); BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    //Do NOT change - memory cache's parameters - dependency
    parameter NWAY_W   = $clog2(N_WAYS),  //Cache Ways Width
    parameter FE_NBYTES  = FE_DATA_W/8,        //Number of Bytes per Word
    parameter FE_BYTES_W  = $clog2(FE_NBYTES), //Byte Offset
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTES_W = $clog2(BE_NBYTES), //Offset of Number of Bytes
    //Cache-Memory base Offset
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W),//Logarithm Ratio between the size of the cache-line and the BE's data width 
    /*---------------------------------------------------*/
    //AXI specific parameters
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0,  //AXI ID value
    //Controller's options
    parameter CTRL_CACHE = 0, //Adds a Controller to the cache, to use functions sent by the master or count the hits and misses
    parameter CTRL_CNT = 0  //Counters for Cache Hits and Misses - Disabling this and previous, the Controller only store the buffer states and allows cache invalidation
    ) 
   (
    input                                        clk,
    input                                        reset,
    //Master i/f
    input                                        valid,
`ifdef WORD_ADDR   
    input [CTRL_CACHE + FE_ADDR_W -1:FE_BYTES_W] addr, //MSB is used for Controller selection
`else
    input [CTRL_CACHE + FE_ADDR_W -1:0]          addr, //MSB is used for Controller selection
`endif
    input [FE_DATA_W-1:0]                        wdata,
    input [FE_NBYTES-1:0]                        wstrb,
    output [FE_DATA_W-1:0]                       rdata,
    output                                       ready,
    //Slave i/f -AXI
    //Address Read
    output                                       axi_arvalid, 
    output [BE_ADDR_W-1:0]                       axi_araddr, 
    output [7:0]                                 axi_arlen,
    output [2:0]                                 axi_arsize,
    output [1:0]                                 axi_arburst,
    output [0:0]                                 axi_arlock,
    output [3:0]                                 axi_arcache,
    output [2:0]                                 axi_arprot,
    output [3:0]                                 axi_arqos,
    output [AXI_ID_W-1:0]                        axi_arid,
    input                                        axi_arready,
    //Read
    input                                        axi_rvalid, 
    input [BE_DATA_W-1:0]                        axi_rdata,
    input [1:0]                                  axi_rresp,
    input                                        axi_rlast, 
    output                                       axi_rready,
    // Address Write
    output                                       axi_awvalid,
    output [BE_ADDR_W-1:0]                       axi_awaddr,
    output [7:0]                                 axi_awlen,
    output [2:0]                                 axi_awsize,
    output [1:0]                                 axi_awburst,
    output [0:0]                                 axi_awlock,
    output [3:0]                                 axi_awcache,
    output [2:0]                                 axi_awprot,
    output [3:0]                                 axi_awqos,
    output [AXI_ID_W-1:0]                        axi_awid, 
    input                                        axi_awready,
    //Write
    output                                       axi_wvalid, 
    output [BE_DATA_W-1:0]                       axi_wdata,
    output [BE_NBYTES-1:0]                       axi_wstrb,
    output                                       axi_wlast,
    input                                        axi_wready,
    input                                        axi_bvalid,
    input [1:0]                                  axi_bresp,
    output                                       axi_bready
    );






   
   //internal signals (front-end inputs)
   wire [FE_ADDR_W -1:FE_BYTES_W]                addr_int; 
   wire [FE_DATA_W-1 : 0]                        wdata_int;
   wire [FE_NBYTES-1: 0]                         wstrb_int;
   wire                                          valid_int;
   
   //stored signals
   wire [FE_ADDR_W -1:FE_BYTES_W]                addr_reg; 
   wire [FE_DATA_W-1 : 0]                        wdata_reg;
   wire [FE_NBYTES-1: 0]                         wstrb_reg;
   wire                                          valid_reg;
   
   //cache-memory
   wire                                          hit;
   // write-through buffer
   wire                                          buffer_full, buffer_empty; //cache_memory
   wire                                          buffer_idle, buffer_readen;//back-end
   
   //cache-line replacement
   wire                                          rep_init, rep_valid, rep_line;
   wire [BE_DATA_W-1:0]                          rep_rdata;
   wire [LINE2MEM_DATA_RATIO_W-1:0]              rep_counter;
   wire [FE_ADDR_W -1:BE_BYTES_W+LINE2MEM_W]     rep_addr; 
   
   //cache-control
   wire                                          ctrl_valid, ctrl_ready;   
   wire [`CTRL_ADDR_W-1:0]                       ctrl_addr;
   wire [`CTRL_COUNTER_W+1:0]                    ctrl_wdata;//{buffer_state[1:0], ctrl_counters}   
   wire [FE_DATA_W-1:0]                          ctrl_data;
   wire                                          invalidate;
   
   
   
   
   front_end
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W)
       )
   front_end
     (
      .clk   (clk),
      .reset (reset),
      //front-end port
      .valid (valid),
      .addr  (addr),
      .wdata (wdata),
      .wstrb (wstrb),
      .rdata (rdata),
      .ready (ready),
      //internal input signals
      .valid_int (valid_int),
      .addr_int  (addr_int),
      .wdata_int (wdata_int),
      .wstrb_int (wstrb_int),
      //cache-memory output
      .rdata_int (rdata_int),
      //stored input signals
      .valid_reg (valid_reg),
      .addr_reg  (addr_reg),
      .wdata_reg (wdata_reg),
      .wstrb_reg (wstrb_reg),
      //memory signals
      .hit         (hit),
      .buffer_full (buffer_full),
      //cache-control
      .ctrl_valid (ctrl_valid),
      .ctrl_addr  (ctrl_addr),
      .ctrl_rdata (ctrl_rdata),
      .ctrl_ready (ctrl_ready)
      );
   

   
   cache_memory
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),
       .BE_DATA_W (BE_DATA_W),
       .N_WAYS     (N_WAYS),
       .LINE_OFF_W (LINE_OFF_W),
       .WORD_OFF_W (WORD_OFF_W),
       .REP_POLICY (REP_POLICY),    
       .WTBUF_DEPTH_W (WTBUF_DEPTH_W)
       )
   cache_memory
     (
      .clk   (clk),
      .reset (reset),
      //front-end
      //internal
      .valid (valid_int),
      .addr  (addr_int),
      .wdata (wdata_int),
      .wstrb (wstrb_int),
      .rdata (rdata_int),
      //stored
      .valid_reg (valid_reg),   
      .addr_reg  (addr_reg),
      .wdata_reg (wdata_reg),
      .wstrb_reg (wstrb_reg),
      //cache-memory signals
      .hit       (hit), 
      //back-end
      //write-through-buffer (write-channel)
      .buffer_full   (buffer_full),
      .buffer_empty  (buffer_empty),
      .buffer_output (buffer_output),
      .buffer_readen (buffer_readen),
      .buffer_idle   (buffer_idle),
      //cache-line replacement (read-channel)
      .rep_init    (rep_init),
      .rep_addr    (rep_addr),
      .rep_rdata   (rep_rdata),
      .rep_valid   (rep_valid),
      .rep_line    (rep_line),
      .rep_counter (rep_counter),
      //control's signals
      .ctrl_wdata (ctrl_wdata),
      .invalidate (invalidate)
      );



   
   back_end_native
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),  
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WORD_OFF_W (WORD_OFF_W)
       )
   back_end
     (
      .clk(clk),
      .reset(reset),
      //write-through-buffer (write-channel)
      .buffer_full   (buffer_full),
      .buffer_empty  (buffer_empty),
      .buffer_output (buffer_output),
      .buffer_readen (buffer_readen),
      .buffer_idle   (buffer_idle),
      //cache-line replacement (read-channel)
      .rep_init    (rep_init),
      .rep_addr    (rep_addr),
      .rep_data    (rep_data),
      .rep_valid   (rep_valid),
      .rep_line    (rep_line),
      .rep_counter (rep_counter),
      //back-end read-channel
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
      .axi_rready(axi_rready),
      //back-end write-channel
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
   
   
   
   generate
      if (CTRL_CACHE)
         
        cache_control
          #(
            .FE_DATA_W  (FE_DATA_W),
            .CTRL_CNT   (CTRL_CNT)
            )
      cache_control
        (
         .clk   (clk),
         .reset (reset),
         //control's signals
         .ctrl_valid (ctrl_valid),
         .ctrl_addr  (ctrl_addr),
         .ctrl_wdata (ctrl_wdata),
         .ctrl_rdata (ctrl_rdata),
         .ctrl_ready (ctrl_ready),
         .invalidate (invalidate)
         );
      
   endgenerate

endmodule // iob_cache_axi


