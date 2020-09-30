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
    parameter BYTES_W  = $clog2(FE_NBYTES), //Byte Offset
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTES_W = $clog2(BE_NBYTES), //Offset of Number of Bytes
    //Cache-Memory base Offset
    parameter LINE2MEM_DATA_RATIO_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W),//Logarithm Ratio between the size of the cache-line and the BE's data width 
    //Look-ahead Interface - Store Front-End input signals
    parameter LA_INTERF = 0,
    /*---------------------------------------------------*/
  
    //Controller's options
    parameter CTRL_CACHE = 0, //Adds a Controller to the cache, to use functions sent by the master or count the hits and misses
    parameter CTRL_CNT = 1  //Counters for Cache Hits and Misses - Disabling this and previous, the Controller only store the buffer states and allows cache invalidation
    ) 
   (
    input                                               clk,
    input                                               reset,
`ifdef WORD_ADDR   
    input [CTRL_CACHE + FE_ADDR_W -1:$clog2(FE_NBYTES)] addr, //MSB is used for Controller selection
`else
    input [CTRL_CACHE + FE_ADDR_W -1:0]                 addr, //MSB is used for Controller selection
`endif
    input [FE_DATA_W-1:0]                               wdata,
    input [FE_NBYTES-1:0]                               wstrb,
    output reg [FE_DATA_W-1:0]                          rdata,
    input                                               valid,
    output                                              ready,
    //Native interface
    output [BE_ADDR_W-1:0]                              mem_addr,
    output                                              mem_valid,
    input                                               mem_ready,
    output [BE_DATA_W-1:0]                              mem_wdata,
    output [BE_NBYTES-1:0]                              mem_wstrb,
    input [BE_DATA_W-1:0]                               mem_rdata
    );
   
   //Internal signals
   wire [CTRL_CACHE + FE_ADDR_W -1:$clog2(FE_NBYTES)]   addr_int;  //MSB is the Ctrl's select
   wire                                                 valid_int;
   wire [FE_DATA_W-1 : 0]                               wdata_int;
   wire [FE_NBYTES-1: 0]                                wstrb_int;
   wire                                                 ready_int;
   
   
   //Process connection and controller signals
   wire                                                 read_miss, hit, write_full, write_empty, write_en;
   wire                                                 line_load, line_load_en;
   wire [BE_DATA_W-1:0]                                 line_load_data;
   wire [LINE2MEM_DATA_RATIO_W-1:0]                     word_counter;
   wire [CTRL_CACHE*(`CTRL_COUNTER_W-1):0]              ctrl_counter;
   wire                                                 invalidate;
   
   //Cache - Controller selection
   wire                                                 cache_select; //selects memory cache (1) or controller (0), using addr's MSB //  
   wire                                                 write_access;
   wire                                                 read_access;
   wire                                                 ctrl_select;        
   
   
   //Cache - Memory-Controller signals
   wire [FE_DATA_W-1:0]                                 rdata_cache, rdata_ctrl;
   wire                                                 ready_cache, ready_ctrl;
   wire [2*FE_DATA_W-1:0]                               rdata_ctrlcache;

   generate
      if(CTRL_CACHE) 
        begin
           //Cache - Controller selection
           assign cache_select = ~addr_int[CTRL_CACHE + FE_ADDR_W -1] & valid_int; //selects memory cache (1) or controller (0), using addr's MSB //  
           assign write_access = (cache_select &   (|wstrb_int));
           assign read_access =  (cache_select &  ~(|wstrb_int));
           assign ctrl_select  = addr_int[CTRL_CACHE + FE_ADDR_W -1] & valid_int;

           //Cache - Memory-Controller signals
           assign rdata_ctrlcache = {rdata_ctrl, rdata_cache};
           
           always@*
             rdata = rdata_ctrlcache << FE_DATA_W*ctrl_select; 

           assign ready_int = ready_cache | ready_ctrl;

        end // if (CTRL_CACHE)
      else 
        begin
           assign cache_select = valid_int;
           assign write_access = (valid_int &   (|wstrb_int));
           assign read_access =  (valid_int &  ~(|wstrb_int));

           always@*
             rdata = rdata_cache;
           
           assign ready_int = ready_cache;
           assign invalidate = 1'b0;
           
        end // else: !if(CTRL_CACHE)
   endgenerate

   assign ready = ready_int;

   
   generate
      if (LA_INTERF) //Look-Ahead Interface - signal storage
        begin

           look_ahead_interface 
             #(
               .FE_ADDR_W(FE_ADDR_W),
               .FE_DATA_W(FE_DATA_W),
               .CTRL_CACHE(CTRL_CACHE)
               )
           la_if
             (
              .clk (clk),
              .reset(reset),
              .addr(addr[CTRL_CACHE + FE_ADDR_W -1:$clog2(FE_NBYTES)]),
              .valid(valid),
              .wdata(wdata),
              .wstrb(wstrb),
              .ready_int(ready_int),
              .addr_int(addr_int),
              .valid_int(valid_int),
              .wdata_int(wdata_int),
              .wstrb_int(wstrb_int)
              );
        end
      else
        begin
           //Internal assignment - Direct wiring
           assign addr_int  = addr[CTRL_CACHE + FE_ADDR_W -1:$clog2(FE_NBYTES)];
           assign valid_int = valid;
           assign wdata_int = wdata;
           assign wstrb_int = wstrb;
        end // else: !if(LA_INTERF)
   endgenerate
   


   main_process
     #(
       .LINE_OFF_W(LINE_OFF_W),
       .CTRL_CACHE(CTRL_CACHE),
       .CTRL_CNT(CTRL_CNT)
       )
   main_fsm
     (
      .clk(clk),
      .reset(reset),
      .write_access(write_access),
      .read_access(read_access),
      .read_miss(read_miss),
      .line_load(line_load),
      .hit(hit),
      .write_full(write_full),
      .write_empty(write_empty),
      .ready(ready_cache),
      .write_en(write_en),
`ifdef CACHE_PIPELINE
      .index (addr_int[BYTES_W + WORD_OFF_W +: LINE_OFF_W]),
      .read (~(|wstrb_int)),
`endif
      .ctrl_counter(ctrl_counter)
      );


   
   wire [BE_ADDR_W-1:0] mem_addr_read,  mem_addr_write;
   wire                 mem_valid_read, mem_valid_write;
   
   assign mem_addr =  (line_load)? mem_addr_read : mem_addr_write;
   assign mem_valid = (line_load)? mem_valid_read: mem_valid_write;                   
   
   read_process_native
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),  
       .WORD_OFF_W(WORD_OFF_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W)
       )
   read_fsm
     (
      .clk(clk),
      .reset(reset),
      .addr(addr_int[FE_ADDR_W-1: BE_BYTES_W + LINE2MEM_DATA_RATIO_W]),
      .read_miss(read_miss),
      .line_load(line_load),
      .line_load_en(line_load_en),
      .word_counter(word_counter),
      .line_load_data(line_load_data),
      .mem_addr(mem_addr_read),
      .mem_valid(mem_valid_read),
      .mem_ready(mem_ready),
      .mem_rdata(mem_rdata)  
      );

   write_process_native
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),
       .WTBUF_DEPTH_W(WTBUF_DEPTH_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W)
       )
   write_fsm
     (
      .clk(clk),
      .reset(reset),
      .addr(addr_int[FE_ADDR_W-1:$clog2(FE_NBYTES)]),
      .wstrb(wstrb_int),
      .wdata(wdata_int),
      .write_empty(write_empty),
      .write_full(write_full),
      .write_en(write_en),
      .mem_addr(mem_addr_write),
      .mem_valid(mem_valid_write),
      .mem_ready(mem_ready),
      .mem_wdata(mem_wdata),
      .mem_wstrb(mem_wstrb)
      );
   

   memory_section
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),
       .N_WAYS(N_WAYS),
       .LINE_OFF_W(LINE_OFF_W),
       .WORD_OFF_W(WORD_OFF_W),
       .BE_DATA_W(BE_DATA_W),
       .REP_POLICY(REP_POLICY)
       )
   memory_cache
     (
      .clk  (clk),
      .reset(reset),
      .addr (addr_int[FE_ADDR_W-1:$clog2(FE_NBYTES)]),
      .wdata(wdata_int),
      .wstrb(wstrb_int),
      .rdata(rdata_cache),
      .valid(cache_select),
      .line_load_data(line_load_data),
      .line_load(line_load),
      .line_load_en(line_load_en),
      .word_counter(word_counter),
      .hit(hit),
      .write_en(write_en),
      .invalidate(invalidate)
      );


   generate
      if (CTRL_CACHE)
        cache_controller
          #(
            .FE_DATA_W  (FE_DATA_W),
            .CTRL_CNT   (CTRL_CNT)
            )
      cache_control
        (
         .clk(clk),
         .din(ctrl_counter),
         .invalidate(invalidate),
         .addr(addr_int[$clog2(FE_NBYTES) +: `CTRL_ADDR_W]),
         .dout(rdata_ctrl),
         .valid(ctrl_select),
         .ready(ready_ctrl),
         .reset(reset),
         .write_state({write_full,write_empty})
         );
   endgenerate
   

endmodule // iob_cache



module iob_cache_axi 
  #(
    //memory cache's parameters
    parameter FE_ADDR_W   = 32,       //Address width - width that will used for the cache 
    parameter FE_DATA_W   = 32,       //Data width - word size used for the cache
    parameter N_WAYS   = 8,        //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter LINE_OFF_W  = 4,     //Line-Offset Width - 2**NLINE_W total cache lines
    parameter WORD_OFF_W = 3,      //Word-Offset Width - 2**OFFSET_W total FE_DATA_W words per line - WARNING about LINE2MEM_DATA_RATIO_W (can cause word_counter [-1:0]
    parameter WTBUF_DEPTH_W = 4,   //Depth Width of Write-Through Buffer
    //Replacement policy (N_WAYS > 1)
    parameter REP_POLICY = `LRU, //LRU - Least Recently Used; LRU_stack (LRU that uses shifts as a stack) ; BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    //Do NOT change - memory cache's parameters - dependency
    parameter NWAY_W   = $clog2(N_WAYS), //Cache Ways Width
    parameter FE_NBYTES  = FE_DATA_W/8,       //Number of Bytes per Word
    parameter BYTES_W = $clog2(FE_NBYTES), //Offset of the Number of Bytes per Word
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTES_W = $clog2(BE_NBYTES), //Offset of Number of Bytes
    //AXI specific parameters
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0, //AXI ID value
    //Cache-Memory base Offset
    parameter LINE2MEM_DATA_RATIO_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W), //Logarithm Ratio between the size of the cache-line and the BE's data width 
    //Look-ahead Interface - Store Front-End input signals
    parameter LA_INTERF = 0,
    /*---------------------------------------------------*/
    //Controller's options
    parameter CTRL_CACHE = 1, //Adds a Controller to the cache, to use functions sent by the master or count the hits and misses
    parameter CTRL_CNT = 1   //Counters for Cache Hits and Misses - Disabling this and previous, the Controller only store the buffer states and allows cache invalidations
    ) 
   (
    input                                               clk,
    input                                               reset,
`ifdef WORD_ADDR   
    input [CTRL_CACHE + FE_ADDR_W -1:$clog2(FE_NBYTES)] addr, //MSB is used for Controller selection
`else
    input [CTRL_CACHE + FE_ADDR_W -1:0]                 addr, //MSB is used for Controller selection
`endif
    input [FE_DATA_W-1:0]                               wdata,
    input [FE_NBYTES-1:0]                               wstrb,
    output reg [FE_DATA_W-1:0]                          rdata,
    input                                               valid,
    output                                              ready,

    // AXI interface 
    // Address Write
    output [AXI_ID_W-1:0]                               axi_awid, 
    output [BE_ADDR_W-1:0]                              axi_awaddr,
    output [7:0]                                        axi_awlen,
    output [2:0]                                        axi_awsize,
    output [1:0]                                        axi_awburst,
    output [0:0]                                        axi_awlock,
    output [3:0]                                        axi_awcache,
    output [2:0]                                        axi_awprot,
    output [3:0]                                        axi_awqos,
    output                                              axi_awvalid,
    input                                               axi_awready,
    //Write
    output [BE_DATA_W-1:0]                              axi_wdata,
    output [BE_NBYTES-1:0]                              axi_wstrb,
    output                                              axi_wlast,
    output                                              axi_wvalid, 
    input                                               axi_wready,
    input [1:0]                                         axi_bresp,
    input                                               axi_bvalid,
    output                                              axi_bready,
    //Address Read
    output [AXI_ID_W-1:0]                               axi_arid,
    output [BE_ADDR_W-1:0]                              axi_araddr, 
    output [7:0]                                        axi_arlen,
    output [2:0]                                        axi_arsize,
    output [1:0]                                        axi_arburst,
    output [0:0]                                        axi_arlock,
    output [3:0]                                        axi_arcache,
    output [2:0]                                        axi_arprot,
    output [3:0]                                        axi_arqos,
    output                                              axi_arvalid, 
    input                                               axi_arready,
    //Read
    input [BE_DATA_W-1:0]                               axi_rdata,
    input [1:0]                                         axi_rresp,
    input                                               axi_rlast, 
    input                                               axi_rvalid, 
    output                                              axi_rready
    );
   
   //Internal signals
   wire [CTRL_CACHE + FE_ADDR_W -1 : $clog2(FE_NBYTES)] addr_int;
   wire                                                 valid_int;
   wire [FE_DATA_W-1: 0]                                wdata_int;
   wire [FE_NBYTES-1: 0]                                wstrb_int;
   wire                                                 ready_int;
   
   
   //Process connection and controller signals
   wire                                                 read_miss, hit, write_full, write_empty, write_en;
   wire                                                 line_load, line_load_en;
   wire [BE_DATA_W-1:0]                                 line_load_data;
   wire [LINE2MEM_DATA_RATIO_W-1:0]                     word_counter;
   wire [CTRL_CACHE*(`CTRL_COUNTER_W-1):0]              ctrl_counter;
   wire                                                 invalidate;

   //Cache - Controller selection
   wire                                                 cache_select; //selects memory cache (1) or controller (0), using addr's MSB //  
   wire                                                 write_access;
   wire                                                 read_access;
   wire                                                 ctrl_select;        
   
   
   //Cache - Memory-Controller signals
   wire [FE_DATA_W-1:0]                                 rdata_cache, rdata_ctrl;
   wire                                                 ready_cache, ready_ctrl;
   wire [2*FE_DATA_W-1:0]                               rdata_ctrlcache;

   generate
      if(CTRL_CACHE) 
        begin
           //Cache - Controller selection
           assign cache_select = ~addr_int[CTRL_CACHE + FE_ADDR_W -1] & valid_int; //selects memory cache (1) or controller (0), using addr's MSB //  
           assign write_access = (cache_select &   (|wstrb_int));
           assign read_access =  (cache_select &  ~(|wstrb_int));
           assign ctrl_select  = addr_int[CTRL_CACHE + FE_ADDR_W -1] & valid_int;

           //Cache - Memory-Controller signals
           assign rdata_ctrlcache = {rdata_ctrl, rdata_cache};
           
           always@*
             rdata = rdata_ctrlcache << FE_DATA_W*ctrl_select;
           
           assign ready_int = ready_cache | ready_ctrl;
           
        end // if (CTRL_CACHE)
      else 
        begin
           assign cache_select = valid_int;
           assign write_access = (valid_int &   (|wstrb_int));
           assign read_access =  (valid_int &  ~(|wstrb_int));

           always@*
             rdata = rdata_cache;
           
           assign ready_int = ready_cache;
           assign invalidate = 1'b0;
           
        end // else: !if(CTRL_CACHE)
   endgenerate
   
   assign ready = ready_int;

   
   generate
      if (LA_INTERF) //Look-Ahead Interface - signal storage
        begin

           look_ahead_interface 
             #(
               .FE_ADDR_W(FE_ADDR_W),
               .FE_DATA_W(FE_DATA_W),
               .CTRL_CACHE(CTRL_CACHE)
               )
           la_if
             (
              .clk (clk),
              .reset(reset),
              .addr(addr[CTRL_CACHE + FE_ADDR_W -1:$clog2(FE_NBYTES)]),
              .valid(valid),
              .wdata(wdata),
              .wstrb(wstrb),
              .ready_int(ready_int),
              .addr_int(addr_int),
              .valid_int(valid_int),
              .wdata_int(wdata_int),
              .wstrb_int(wstrb_int)
              );
        end
      else
        begin
           //Internal assignment - Direct wiring
           assign addr_int  = addr[CTRL_CACHE + FE_ADDR_W -1:$clog2(FE_NBYTES)];
           assign valid_int = valid;
           assign wdata_int = wdata;
           assign wstrb_int = wstrb;
        end // else: !if(LA_INTERF)
   endgenerate
   


   main_process
     #(
       .LINE_OFF_W(LINE_OFF_W),
       .CTRL_CACHE(CTRL_CACHE),
       .CTRL_CNT(CTRL_CNT)
       )
   main_fsm
     (
      .clk(clk),
      .reset(reset),
      .write_access(write_access),
      .read_access(read_access),
      .read_miss(read_miss),
      .line_load(line_load),
      .hit(hit),
      .write_full(write_full),
      .write_empty(write_empty),
      .ready(ready_cache),
      .write_en(write_en),
`ifdef CACHE_PIPELINE
      .index (addr_int[BYTES_W + WORD_OFF_W +: LINE_OFF_W]),
      .read (~(|wstrb_int)),
`endif
      .ctrl_counter(ctrl_counter)
      );


   
   read_process_axi
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),  
       .WORD_OFF_W(WORD_OFF_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .AXI_ID_W(AXI_ID_W),
       .AXI_ID(AXI_ID)
       )
   read_fsm
     (
      .clk(clk),
      .reset(reset),
      .addr(addr_int[FE_ADDR_W-1:LINE2MEM_DATA_RATIO_W + BE_BYTES_W]),
      .read_miss(read_miss), 
      .line_load(line_load),
      .line_load_en(line_load_en),
      .word_counter(word_counter),
      .line_load_data (line_load_data),
      .axi_arid(axi_arid),
      .axi_araddr(axi_araddr), 
      .axi_arlen(axi_arlen),
      .axi_arsize(axi_arsize),
      .axi_arburst(axi_arburst),
      .axi_arlock(axi_arlock),
      .axi_arcache(axi_arcache),
      .axi_arprot(axi_arprot),
      .axi_arqos(axi_arqos),
      .axi_arvalid(axi_arvalid), 
      .axi_arready(axi_arready),
      .axi_rdata(axi_rdata),
      .axi_rresp(axi_rresp),
      .axi_rlast(axi_rlast), 
      .axi_rvalid(axi_rvalid), 
      .axi_rready(axi_rready)  
      );

   write_process_axi
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),
       .WTBUF_DEPTH_W(WTBUF_DEPTH_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .AXI_ID_W(AXI_ID_W),
       .AXI_ID(AXI_ID)
       )
   write_fsm
     (
      .clk(clk),
      .reset(reset),
      .addr(addr_int[FE_ADDR_W-1:$clog2(FE_NBYTES)]),
      .wstrb(wstrb_int),
      .wdata(wdata_int),
      .write_empty(write_empty),
      .write_full(write_full),
      .write_en(write_en),
      .axi_awid(axi_awid),
      .axi_awaddr(axi_awaddr), 
      .axi_awlen(axi_awlen),
      .axi_awsize(axi_awsize),
      .axi_awburst(axi_awburst),
      .axi_awlock(axi_awlock),
      .axi_awcache(axi_awcache),
      .axi_awprot(axi_awprot),
      .axi_awqos(axi_awqos),
      .axi_awvalid(axi_awvalid), 
      .axi_awready(axi_awready),
      .axi_wdata(axi_wdata),
      .axi_wstrb(axi_wstrb),
      .axi_wlast(axi_wlast),
      .axi_wvalid(axi_wvalid),
      .axi_wready(axi_wready),
      .axi_bresp(axi_bresp),
      .axi_bvalid(axi_bvalid), 
      .axi_bready(axi_bready)  
      );      
   

   memory_section
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),
       .N_WAYS(N_WAYS),
       .LINE_OFF_W(LINE_OFF_W),
       .WORD_OFF_W(WORD_OFF_W),
       .BE_DATA_W(BE_DATA_W),
       .REP_POLICY(REP_POLICY)
       )
   memory_cache
     (
      .clk  (clk),
      .reset(reset),
      .addr (addr_int[FE_ADDR_W-1:$clog2(FE_NBYTES)]),
      .wdata(wdata_int),
      .wstrb(wstrb_int),
      .rdata(rdata_cache),
      .valid(cache_select),
      .line_load_data(line_load_data),
      .line_load(line_load),
      .line_load_en(line_load_en),
      .word_counter(word_counter),
      .hit(hit),
      .write_en(write_en),
      .invalidate(invalidate)
      );

   generate
      if (CTRL_CACHE)
        cache_controller
          #(
            .FE_DATA_W  (FE_DATA_W),
            .CTRL_CNT   (CTRL_CNT)
            )
      cache_control
        (
         .clk(clk),
         .din(ctrl_counter),
         .invalidate(invalidate),
         .addr(addr_int[$clog2(FE_NBYTES) +: `CTRL_ADDR_W]),
         .dout(rdata_ctrl),
         .valid(ctrl_select),
         .ready(ready_ctrl),
         .reset(reset),
         .write_state({write_full,write_empty})
         );
   endgenerate
   

endmodule // iob_cache_axi




/*----------------------*/
/* Look-ahead Interface */
/*----------------------*/
//Stores necessary signals for correct cache's behaviour
module look_ahead_interface
  #(
    parameter FE_ADDR_W = 32,
    parameter FE_DATA_W = 32,
    parameter FE_NBYTES = FE_DATA_W/8,
    parameter CTRL_CACHE = 1
    )
   (
    //Input signals
    input                                                clk,
    input                                                reset,
    input [CTRL_CACHE + FE_ADDR_W -1:$clog2(FE_NBYTES)]  addr, 
    input [FE_DATA_W-1:0]                                wdata,
    input [FE_NBYTES-1:0]                                wstrb,
    input                                                valid,
    //Internal stored signals
    input                                                ready_int, //Ready to update registers
    output [CTRL_CACHE + FE_ADDR_W -1:$clog2(FE_NBYTES)] addr_int, //MSB is Ctrl's select
    output [FE_DATA_W-1:0]                               wdata_int,
    output [FE_NBYTES-1:0]                               wstrb_int,
    output                                               valid_int
    );
   
   reg [CTRL_CACHE + FE_ADDR_W -1 : $clog2(FE_NBYTES)]   addr_la;
   reg                                                   valid_la;
   reg [FE_DATA_W-1 : 0]                                 wdata_la;
   reg [FE_NBYTES-1: 0]                                  wstrb_la;

   always @(posedge clk, posedge reset) //ready acts as a reset
     begin
        if(reset)
          begin
             addr_la  <= 0;
             valid_la <= 0;
             wdata_la <= 0;
             wstrb_la <= 0;
          end
        else
          if(ready_int)
            begin
               addr_la  <= 0;
               valid_la <= 0;
               wdata_la <= 0;
               wstrb_la <= 0;
            end
          else
            if(valid) //updates
              begin
                 addr_la  <= addr;
                 valid_la <= 1'b1;
                 wdata_la <= wdata;
                 wstrb_la <= wstrb;
              end
            else 
              begin
                 addr_la  <= addr_la;
                 valid_la <= valid_la;
                 wdata_la <= wdata_la;
                 wstrb_la <= wstrb_la;
              end // else: !if(valid)
     end // always @ (posedge clk, posedge ready_int)
   
   //Internal assignment - Multiplexers (so there is no delay)
   assign addr_int  = (valid_la)? addr_la  : addr;
   assign valid_int = (valid_la)? 1'b1     :valid;
   assign wdata_int = (valid_la)? wdata_la :wdata;
   assign wstrb_int = (valid_la)? wstrb_la :wstrb;
   
endmodule // look_ahead_interface


/*--------------*/
/* Main Process */ 
/*--------------*/
//Cache's main process, that controls the current cache's state based on the other processes

module main_process
  #(
    parameter LINE_OFF_W = 4,
    parameter CTRL_CACHE = 1,
    parameter CTRL_CNT = 1
    )
   (
    input                                     clk,
    input                                     reset,
    input                                     write_access,
    input                                     read_access,
    output reg                                read_miss, 
    input                                     line_load,
    input                                     hit,
    input                                     write_full,
    input                                     write_empty,
    output reg                                ready,
    output reg                                write_en,
`ifdef CACHE_PIPELINE
    input [LINE_OFF_W-1:0]                    index,
    input                                     read,
`endif
    output [CTRL_CACHE*(`CTRL_COUNTER_W-1):0] ctrl_counter
    );
   
   
   localparam
     idle          = 2'd0,
     write_standby = 2'd1,
     read_standby  = 2'd2,
     read_process  = 2'd3;


`ifdef CACHE_PIPELINE
   reg [LINE_OFF_W-1:0]                       index_prev;
   reg                                        write_prev;
   
   wire                                       index_seq_read = (index_prev == index) & (~write_prev); //Sequential access to the same index that was NOT a write (write-read-latency on the same address, register output on BRAMs)
   
   always @ (posedge clk) 
     begin
        index_prev <= index;
        write_prev <= write_access;
     end
`endif
   
   
   reg [1:0]                                  state;
   
   always @(posedge clk, posedge reset)
     begin
        if (reset)
          state <= idle;
        else
          case (state)
            idle:
              begin
                 if (read_access)
`ifdef CACHE_PIPELINE
                   if(hit & index_seq_read)
                     state <= idle;
                   else
`endif
                     state <= read_standby;
                 
                 else
                   if(write_access)
                     state <= write_standby;
                   else
                     state <= idle;
              end
            
            write_standby:
              begin
                 if (write_full)
                   state <= write_standby;
                 else
                   state <= idle;
              end

            read_standby:
              begin
                 if(hit)
                   state <= idle;
                 else 
                   if(write_empty)   
                     state <= read_process; //read-miss, needs a line load
                   else
                     state <= read_standby;
              end

            read_process: //line_load
              begin
                 if (~line_load)
                   state <= idle;
                 else
                   state <= read_process;
              end

            default:;

          endcase // case (state)
     end // always @ (posedge clk, posedge reset)


   always @*
     begin
        read_miss = 1'b0;
        ready = 1'b0;
        write_en = 1'b0;
        
	case (state)
          idle:
            begin
`ifdef CACHE_PIPELINE
               ready = hit & index_seq_read & read;
               write_en = hit & index_seq_read & read;   
`else
               ready = 1'b0;
               write_en = 1'b0;
`endif
               
            end

          write_standby:
            begin
               ready = ~write_full; // ends process if isn't full, regardless if hit or miss
               write_en = ~write_full;
            end
          

          read_standby:
            begin
               ready = hit; // if it was a hit, the data in rdata is the correct one
               write_en = hit; //update replacement policy algorithm
               if(~hit & write_empty)
                 read_miss = 1'b1; //so the hit signal is properly updated (memory read-latency) and only starts after everything has been written to the top memory
            end
          
          read_process:
            begin  
               write_en = ~line_load;
               ready = ~line_load;                           
            end
        endcase
     end

   generate
      if (CTRL_CACHE)
        begin
           if(CTRL_CNT)
             begin
                reg [`CTRL_COUNTER_W-1:0] ctrl_counter_reg;
                
                always @*
                  begin
                     ctrl_counter_reg = `CTRL_COUNTER_W'd0;
                     
	             case (state)
                       idle:
                         ctrl_counter_reg = `CTRL_COUNTER_W'd0;

                       write_standby:
                         if (~write_full)
                           if(hit)
                             ctrl_counter_reg = `WRITE_HIT;
                           else
                             ctrl_counter_reg = `WRITE_MISS;
                         else
                           ctrl_counter_reg = `CTRL_COUNTER_W'd0;
                       

                       read_standby:
                         if (hit)
                           ctrl_counter_reg = `READ_HIT;
                         else
                           if(write_empty)
                             ctrl_counter_reg = `READ_MISS;
                           else
                             ctrl_counter_reg = `CTRL_COUNTER_W'd0;         
                     endcase // case (state)
                     
                  end // always @ *

                assign ctrl_counter = ctrl_counter_reg;
             end
           else
             begin
                assign ctrl_counter = {`CTRL_COUNTER_W{1'bx}}; //Don't care, isn't used
             end // else: !if(CTRL_CNT)
        end
      else
        begin
           assign  ctrl_counter = 1'bx; //Don't care, isn't used
        end // else: !if(CTRL_CACHE)
      
   endgenerate
   
   
endmodule            


/*--------------*/
/* Read Process */ 
/*--------------*/
// Process that loads a cache line, in the occurence of a read-miss

module read_process_axi 
  #(
    parameter FE_ADDR_W   = 32,
    parameter FE_DATA_W   = 32,
    parameter WORD_OFF_W = 3,
    parameter FE_NBYTES  = FE_DATA_W/8,
    parameter BYTES_W = $clog2(FE_NBYTES), //Offset of the Number of Bytes per Word
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTES_W = $clog2(BE_NBYTES), //Offset of the Number of Bytes
    //AXI specific parameters
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0,  //AXI ID value
    //Cache-Memory base Offset
    parameter LINE2MEM_DATA_RATIO_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W) //Logarithm Ratio between the size of the cache-line and the BE's data width 
    )
   (
    input                                                    clk,
    input                                                    reset,
    input [FE_ADDR_W -1: LINE2MEM_DATA_RATIO_W + BE_BYTES_W] addr,
    input                                                    read_miss, //read access that results in a cache miss
    output reg                                               line_load, //load cache line with new data
    output                                                   line_load_en,//Memory enable during the cache line load
    output reg [LINE2MEM_DATA_RATIO_W-1:0]                   word_counter,//counter to enable each word in the line
    output [BE_DATA_W-1:0]                                   line_load_data,//data to load the cache line  
    // AXI interface  
    //Address Read
    output [AXI_ID_W-1:0]                                    axi_arid,
    output [BE_ADDR_W-1:0]                                   axi_araddr, 
    output [7:0]                                             axi_arlen,
    output [2:0]                                             axi_arsize,
    output [1:0]                                             axi_arburst,
    output [0:0]                                             axi_arlock,
    output [3:0]                                             axi_arcache,
    output [2:0]                                             axi_arprot,
    output [3:0]                                             axi_arqos,
    output reg                                               axi_arvalid, 
    input                                                    axi_arready,
    //Read
    input [BE_DATA_W-1:0]                                    axi_rdata,
    input [1:0]                                              axi_rresp,
    input                                                    axi_rlast, 
    input                                                    axi_rvalid, 
    output reg                                               axi_rready
    );

   generate
      if(LINE2MEM_DATA_RATIO_W > 0)
        begin
           
           //Constant AXI signals
           assign axi_arid    = AXI_ID;
           assign axi_arlock  = 1'b0;
           assign axi_arcache = 4'b0011;
           assign axi_arprot  = 3'd0;
           assign axi_arqos   = 4'd0;
           //Burst parameters
           assign axi_arlen   = 2**LINE2MEM_DATA_RATIO_W -1; //will choose the burst lenght depending on the cache's and slave's data width
           assign axi_arsize  = BE_BYTES_W; //each word will be the width of the memory for maximum bandwidth
           assign axi_arburst = 2'b01; //incremental burst
           assign axi_araddr  = {{BE_ADDR_W{1'b0}}+addr[FE_ADDR_W-1:LINE2MEM_DATA_RATIO_W + BE_BYTES_W], {(LINE2MEM_DATA_RATIO_W+BE_BYTES_W){1'b0}}}; //base address for the burst, with width extension 

           //Line Load signals
           assign line_load_en   = axi_rvalid;
           assign line_load_data = axi_rdata;
           
           
           localparam
             idle          = 2'd0,
             init_process  = 2'd1,
             load_process  = 2'd2,
             end_process   = 2'd3;
           
           
           reg [1:0]                           state;
           reg                                 error;//axi error during reply (axi_rresp[1] == 1) - burst can't be interrupted, so a flag needs to be active
           
           
           always @(posedge clk, posedge reset)
             begin
                if(reset)
                  begin
                     state <= idle;
                     word_counter <= 0;
                     error <= 0;
                  end
                else
                  begin
                     error <= error;
                     case (state)   
                       idle:
                         begin
                            error <= 0;
                            word_counter <= 0;  
                            if(read_miss)
                              state <= init_process;
                            else
                              state <= idle;
                         end

                       init_process:
                         begin
                            error <= 0;
                            word_counter <= 0;  
                            if(axi_arready)
                              state <= load_process;
                            else
                              state <= init_process;
                         end

                       load_process:
                         begin
                            if(axi_rvalid)
                              if(axi_rlast)
                                begin
                                   state <= end_process;
                                   word_counter <= word_counter; //to avoid writting last data in first line word
                                   if(axi_rresp[1]) //error - received at the same time as the valid - needs to wait until the end to start all over - going directly to init_process would cause a stall to this burst
                                     error <= 1;
                                end
                              else
                                begin
                                   word_counter <= word_counter +1;
                                   state <= load_process;
                                   if(axi_rresp != 2'b00) //error - received at the same time as the valid - needs to wait until the end to start all over - going directly to init_process would cause a stall to this burst
                                     error <= 1;
                                end
                            else
                              begin
                                 word_counter <= word_counter;
                                 state <= load_process;
                              end
                         end

                       end_process://delay for the read_latency of the memories (if the rdata is the last word)
                         if (error)
                           state <= init_process;
                         else
                           state <= idle;
                       
                       default:;
                     endcase
                  end
             end
           
           always @*
             begin
                axi_arvalid  = 1'b0;
                axi_rready   = 1'b0;
                line_load    = 1'b0;
                case(state)

                  idle:
                    begin
                       line_load    = 1'b0;
                       axi_arvalid  = 1'b0;
                       axi_rready   = 1'b0;
                    end
                  
                  init_process:
                    begin
                       line_load   = 1'b1;
                       axi_arvalid = 1'b1;
                       axi_rready  = 1'b0;
                    end

                  load_process:
                    begin
                       line_load   = 1'b1;
                       axi_arvalid = 1'b0;
                       axi_rready  = 1'b1;             
                    end

                  end_process:
                    line_load = 1'b1; //delay for the memory update (read-latency)
                  
                  default:;
                  
                endcase
             end // always @ *
        end // if (LINE2MEM_DATA_RATIO_W > 0)

      
      else
         
        begin
           //Constant AXI signals
           assign axi_arid    = AXI_ID;
           assign axi_arlock  = 1'b0;
           assign axi_arcache = 4'b0011;
           assign axi_arprot  = 3'd0;
           assign axi_arqos   = 4'd0;
           //Burst parameters - single 
           assign axi_arlen   = 8'd0; //A single burst of Memory data width word
           assign axi_arsize  = BE_BYTES_W; //each word will be the width of the memory for maximum bandwidth
           assign axi_arburst = 2'b00; 
           assign axi_araddr  = {{BE_ADDR_W{1'b0}}+addr[FE_ADDR_W-1:LINE2MEM_DATA_RATIO_W + BE_BYTES_W], {(LINE2MEM_DATA_RATIO_W+BE_BYTES_W){1'b0}}}; //base address for the burst, with width extension 

           //Line Load signals
           assign line_load_en   = axi_rvalid;
           assign line_load_data = axi_rdata;
           
           
           localparam
             idle          = 2'd0,
             init_process  = 2'd1,
             load_process  = 2'd2,
             end_process   = 2'd3;
           
           
           reg [1:0]                           state;

           
           always @(posedge clk, posedge reset)
             begin
                if(reset)
                   
                  state <= idle;
                
                else
                   
                  case (state)   
                    idle:
                      begin
                         if(read_miss)
                           state <= init_process;
                         else
                           state <= idle;
                      end

                    init_process:
                      begin                      
                         if(axi_arready)
                           state <= load_process;
                         else
                           state <= init_process;
                      end

                    load_process:
                      begin
                         if(axi_rvalid)
                           if(axi_rresp[1]) //error - received at the same time as valid
                             state <= init_process;
                           else
                             state <= end_process;
                         else
                           state <= load_process;
                      end

                    end_process://delay for the read_latency of the memories (if the rdata is the last word)
                      state <= idle;
                    
                    
                    default:;
                  endcase
             end
           
           
           always @*
             begin
                axi_arvalid  = 1'b0;
                axi_rready   = 1'b0;
                line_load    = 1'b0;
                case(state)

                  idle:
                    begin
                       line_load    = 1'b0;
                       axi_arvalid  = 1'b0;
                       axi_rready   = 1'b0;
                    end
                  
                  init_process:
                    begin
                       line_load   = 1'b1;
                       axi_arvalid = 1'b1;
                       axi_rready  = 1'b0;
                    end

                  load_process:
                    begin
                       line_load   = 1'b1;
                       axi_arvalid = 1'b0;
                       axi_rready  = 1'b1;             
                    end

                  end_process:
                    line_load = 1'b1; //delay for the memory update (read-latency)
                  
                  default:;
                  
                endcase
             end // always @ *
           
        end     
   endgenerate 
   
endmodule



module read_process_native
  #(
    parameter FE_ADDR_W   = 32,
    parameter FE_DATA_W   = 32,
    parameter FE_NBYTES  = FE_DATA_W/8,
    parameter WORD_OFF_W = 3,
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTES_W = $clog2(BE_NBYTES), //Offset of the Number of Bytes
    //Cache-Memory base Offset
    parameter LINE2MEM_DATA_RATIO_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W) //burst offset based on the cache word's and memory word size
    )
   (
    input                                                    clk,
    input                                                    reset,
    input [FE_ADDR_W -1: BE_BYTES_W + LINE2MEM_DATA_RATIO_W] addr,
    input                                                    read_miss, //read access that results in a cache miss
    output reg                                               line_load, //load cache line with new data
    output                                                   line_load_en,//Memory enable during the cache line load
    output reg [LINE2MEM_DATA_RATIO_W-1:0]                   word_counter,//counter to enable each word in the line
    output [BE_DATA_W-1:0]                                   line_load_data,//data to load the cache line  
    //Native memory interface
    output [BE_ADDR_W -1:0]                                  mem_addr,
    output reg                                               mem_valid,
    input                                                    mem_ready,
    input [BE_DATA_W-1:0]                                    mem_rdata
    );

   generate
      if (LINE2MEM_DATA_RATIO_W > 0)
        begin
           assign mem_addr  = {BE_ADDR_W{1'b0}} + {addr[FE_ADDR_W -1: BE_BYTES_W + LINE2MEM_DATA_RATIO_W], word_counter, {BE_BYTES_W{1'b0}} };
           
           //Cache Line Load signals
           //assign line_load_en = mem_ready & mem_valid & line_load;
           assign line_load_en = mem_ready & mem_valid; //doesn require line_load since when mem_valid is HIGH, so is line_load.
           assign line_load_data = mem_rdata;

           localparam
             idle             = 2'd0,
             handshake        = 2'd1, //the process was divided in 2 handshake steps to cause a delay in the
             end_handshake    = 2'd2; //(always 1 or a delayed valid signal), otherwise it will fail
           
           
           reg [1:0]                                  state;

           always @(posedge clk, posedge reset)
             begin
                if(reset)
                  begin
                     state <= idle;
                     word_counter <=0;
                  end
                else
                  begin
                     word_counter <= word_counter;
                     
                     case(state)

                       idle:
                         begin
                            word_counter <= 0;
                            if(read_miss) //main_process flag
                              state <= handshake;                                        
                            else
                              state <= idle;                      
                         end
                       
                       handshake:
                         begin
                            if(mem_ready)
                              if(word_counter == {LINE2MEM_DATA_RATIO_W{1'b1}})
                                state <= end_handshake;
                              else
                                begin
                                   word_counter <= word_counter +1;
                                   state <= handshake;
                                end
                            else
                              begin
                                 state <= handshake;
                              end
                         end
                       
                       end_handshake: //read-latency delay (last line word)
                         begin
                            state <= idle;
                            word_counter <= 0;
                         end
                       
                       default:;
                       
                     endcase                                                     
                  end         
             end
           
           
           always @*
             begin 
                //word_counter =0;
                
                case(state)
                  
                  idle:
                    begin
                       mem_valid = 1'b0;
                       line_load = 1'b0;
                       //word_counter = 0;
                    end

                  handshake:
                    begin
                       mem_valid = 1'b1;
                       line_load = 1'b1;
                       // word_counter = word_counter;
                    end
                  
                  end_handshake:
                    begin
                       // word_counter = word_counter; //to avoid updating the first word in line with last data
                       line_load = 1'b1; //delay for read-latency
                       mem_valid = 1'b0;
                    end
                  
                  default:
                    begin
                       line_load = 1'b0;
                       mem_valid = 1'b0;
                    end
                  
                endcase
             end
        end // if (MEM_OFF_W > 0)
      else
        begin
           assign mem_addr  = {BE_ADDR_W{1'b0}} + {addr[FE_ADDR_W-1: BE_BYTES_W], {BE_BYTES_W{1'b0}}};
           
           //Cache Line Load signals
           assign line_load_en = mem_ready & mem_valid & line_load;
           assign line_load_data = mem_rdata;

           localparam
             idle             = 2'd0,
             handshake        = 2'd1, //the process was divided in 2 handshake steps to cause a delay in the
             end_handshake    = 2'd2; //(always 1 or a delayed valid signal), otherwise it will fail
           
           
           reg [1:0]                                  state;

           always @(posedge clk, posedge reset)
             begin
                if(reset)
                  state <= idle;
                else
                  begin
                     case(state)

                       idle:
                         begin
                            
                            if(read_miss) //main_process flag
                              state <= handshake;                                        
                            else
                              state <= idle;                      
                         end
                       
                       handshake:
                         begin
                            if(mem_ready)
                              state <= end_handshake;
                            else
                              state <= handshake;
                         end
                       
                       end_handshake: //read-latency delay (last line word)
                         begin
                            state <= idle;
                            word_counter <= 0;
                         end
                       
                       default:;
                       
                     endcase                                                     
                  end         
             end
           
           
           always @*
             begin 
                
                
                case(state)
                  
                  idle:
                    begin
                       mem_valid = 1'b0;
                       line_load = 1'b0;
                    end

                  handshake:
                    begin
                       mem_valid = 1'b1;
                       line_load = 1'b1;
                    end
                  
                  end_handshake:
                    begin
                       line_load = 1'b1; //delay for read-latency
                       mem_valid = 1'b0;
                    end
                  
                  default:;
                  
                endcase
             end
           
        end // else: !if(MEM_OFF_W > 0)
   endgenerate
   
endmodule



/* ------------- */
/* Write process */
/* ------------- */
// Process responsible to write data to the upper-level memory

module write_process_axi
  #(
    parameter FE_ADDR_W   = 32,
    parameter FE_DATA_W   = 32,
    parameter FE_NBYTES  = FE_DATA_W/8,
    parameter BYTES_W = $clog2(FE_NBYTES), //Offset of the Number of Bytes per Word
    parameter WTBUF_DEPTH_W = 4,
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTES_W = $clog2(BE_NBYTES), //Offset of the Number of Bytes
    //AXI specific parameters
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0  //AXI ID value
    ) 
   (
    input                                 clk,
    input                                 reset,
    input [FE_ADDR_W-1:$clog2(FE_NBYTES)] addr,
    input [FE_NBYTES-1:0]                 wstrb,
    input [FE_DATA_W-1:0]                 wdata,
    // Buffer status
    output reg                            write_empty,
    output                                write_full,
    // Buffer write enable
    input                                 write_en,
    // AXI interface 
    // Address Write
    output [AXI_ID_W-1:0]                 axi_awid, 
    output [BE_ADDR_W-1:0]                axi_awaddr,
    output [7:0]                          axi_awlen,
    output [2:0]                          axi_awsize,
    output [1:0]                          axi_awburst,
    output [0:0]                          axi_awlock,
    output [3:0]                          axi_awcache,
    output [2:0]                          axi_awprot,
    output [3:0]                          axi_awqos,
    output reg                            axi_awvalid,
    input                                 axi_awready,
    //Write                  
    output [BE_DATA_W-1:0]                axi_wdata,
    output [BE_NBYTES-1:0]                axi_wstrb,
    output                                axi_wlast,
    output reg                            axi_wvalid, 
    input                                 axi_wready,
    input [1:0]                           axi_bresp,
    input                                 axi_bvalid,
    output reg                            axi_bready
    );

   //Write-through buffer
   wire [FE_NBYTES+(FE_ADDR_W-BYTES_W)+(FE_DATA_W) -1 :0] buffer_dout, buffer_din; 
   reg                                                    buffer_read_en;
   wire                                                   buffer_empty, buffer_full;
   
   assign buffer_din = {addr,wstrb,wdata};

   assign write_full = buffer_full;
   
   //Constant AXI signals
   assign axi_awid    = AXI_ID;
   assign axi_awlen   = 8'd0;
   assign axi_awsize  = BE_BYTES_W; // verify - Writes data of the size of BE_DATA_W
   assign axi_awburst = 2'd0;
   assign axi_awlock  = 1'b0; // 00 - Normal Access
   assign axi_awcache = 4'b0011;
   assign axi_awprot  = 3'd0;
   assign axi_awqos   = 4'd0;
   assign axi_wlast   = axi_wvalid;
   
   //AXI Buffer Output signals
   assign axi_awaddr = {{BE_ADDR_W{1'b0}}+buffer_dout[FE_DATA_W+FE_NBYTES + (BE_BYTES_W-BYTES_W) +: FE_ADDR_W-(BE_BYTES_W)], {BE_BYTES_W{1'b0}}}; 
   generate
      if(BE_DATA_W == FE_DATA_W)
        begin
           assign axi_wstrb = buffer_dout[FE_DATA_W +: FE_NBYTES];
           assign axi_wdata =  {{BE_DATA_W{1'b0}}+buffer_dout[FE_DATA_W-1:0]};
           
        end
      else
        begin
           wire [BE_BYTES_W - BYTES_W -1 :0] addr_shift = buffer_dout[FE_DATA_W+FE_NBYTES +: (BE_BYTES_W-BYTES_W)];//addr[BYTES_W +: (BE_BYTES_W - BYTES_W)]
           assign axi_wstrb = buffer_dout[FE_DATA_W+FE_NBYTES -1 -:FE_NBYTES] << addr_shift * FE_NBYTES;
           assign axi_wdata = buffer_dout[FE_DATA_W -1 : 0] << addr_shift * FE_DATA_W;
        end
   endgenerate
   
   
   localparam
     idle           = 3'd0,
     init_process   = 3'd1,
     addr_process   = 3'd2,
     write_process  = 3'd3,
     verif_process  = 3'd4;  
   
   reg [3:0]                                 state;

   
   always @(posedge clk, posedge reset)
     begin
        if(reset)
          state <= idle;
        else
          case(state)

            idle:
              begin
                 if(buffer_empty)
                   state <= idle;
                 else
                   state <= init_process;
              end

            init_process://update write-through buffer
              begin
                 state <= addr_process;
              end
            
            addr_process:
              begin
                 if(axi_awready)
                   state <= write_process;
                 
                 else
                   state <= addr_process;
              end

            write_process:
              begin
                 if (axi_wready)
                   state <= verif_process;
                 else
                   state <= write_process;
              end

            verif_process: //needs to be after the last word has been written, so this can't be optim
              begin
                 if(axi_bvalid)
                   if(axi_bresp == 2'b00)//00 or 01 - OKAY - needs to be after the last word has been written, so this can't be optimized by removing this state
                     if(buffer_empty)
                       state <= idle;
                     else
                       state <= init_process; //updates buffer.
                   else
                     state <= addr_process; //goes back to transfer the same data.
                 else
                   state <= verif_process;
              end

            default: ;         

          endcase 
     end // always @ (posedge clk, posedge reset)
   
   
   always @*
     begin
        buffer_read_en = 1'b0;
        axi_awvalid    = 1'b0;
        axi_wvalid     = 1'b0;
        axi_bready     = 1'b0;
        write_empty    = 1'b0;        
        case(state)
          idle:
            write_empty = buffer_empty;
          init_process:
            buffer_read_en = 1'b1;
          addr_process:
            axi_awvalid = 1'b1;
          write_process:
            axi_wvalid  = 1'b1;
          verif_process:
            axi_bready  = 1'b1;
          default:;
        endcase
     end       

   
   iob_sync_fifo #(
		    .DATA_WIDTH (FE_NBYTES+FE_ADDR_W-BYTES_W+FE_DATA_W),
		    .ADDRESS_WIDTH   (WTBUF_DEPTH_W)
		    ) 
   write_throught_buffer 
     (
      .rst     (reset               ),
      .data_out(buffer_dout         ), 
      .empty   (buffer_empty        ),
      .read_en (buffer_read_en      ),
      .clk    (clk                 ),    
      .data_in (buffer_din          ), 
      .full    (buffer_full         ),
      .write_en((|wstrb) && write_en)
      );

endmodule


module write_process_native
  #(
    parameter FE_ADDR_W   = 32,
    parameter FE_DATA_W   = 32,
    parameter FE_NBYTES  = FE_DATA_W/8,
    parameter BYTES_W = $clog2(FE_NBYTES), //Offset of the Number of Bytes per Word
    parameter WTBUF_DEPTH_W = 4,
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTES_W = $clog2(BE_NBYTES) //Offset of the Number of Bytes
    ) 
   (
    input                                 clk,
    input                                 reset,
    input [FE_ADDR_W-1:$clog2(FE_NBYTES)] addr,
    input [FE_NBYTES-1:0]                 wstrb,
    input [FE_DATA_W-1:0]                 wdata,
    // Buffer status
    output reg                            write_empty,
    output                                write_full,
    // Buffer write enable
    input                                 write_en,
    //Native Memory interface
    output [BE_ADDR_W -1:0]               mem_addr,
    output reg                            mem_valid,
    input                                 mem_ready,
    output [BE_DATA_W-1:0]                mem_wdata,
    output reg [BE_NBYTES-1:0]            mem_wstrb
   
    );

   //Write-through buffer
   wire [FE_NBYTES+(FE_ADDR_W-BYTES_W)+(FE_DATA_W) -1 :0] buffer_dout, buffer_din; 
   reg                                                    buffer_read_en;
   wire                                                   buffer_empty, buffer_full;
   
   assign buffer_din = {addr,wstrb,wdata};

   assign write_full = buffer_full;
   
   //Native Buffer Output signals
   assign mem_addr = {BE_ADDR_W{1'b0}} + {buffer_dout[FE_DATA_W+FE_NBYTES + (BE_BYTES_W-BYTES_W) +: FE_ADDR_W-(BE_BYTES_W)], {BE_BYTES_W{1'b0}}}; 
   
   localparam
     idle          = 3'd0,
     init_process  = 3'd1,
     write_process = 3'd2;
   
   reg [1:0]                                              state;

   generate
      if(BE_DATA_W == FE_DATA_W)
        begin
           
           assign mem_wdata = buffer_dout [FE_DATA_W -1 : 0];
           
           always @*
             begin
                mem_wstrb = 0;
                case(state)
                  write_process:
                    begin
                       mem_wstrb = buffer_dout [FE_DATA_W +: FE_NBYTES];
                    end
                  default:;
                endcase // case (state)
             end // always @ *
           
        end
      else
        begin
           
           wire [BE_BYTES_W - BYTES_W -1 :0] addr_shift = buffer_dout[FE_DATA_W+FE_NBYTES +: (BE_BYTES_W-BYTES_W)];//addr[BYTES_W +: (BE_BYTES_W - BYTES_W)]
           assign mem_wdata = buffer_dout [FE_DATA_W -1 : 0] << addr_shift * FE_DATA_W ;
           
           always @*
             begin
                mem_wstrb = 0;
                case(state)
                  write_process:
                    begin
                       mem_wstrb = buffer_dout[FE_DATA_W+FE_NBYTES -1 -:FE_NBYTES] << addr_shift * FE_NBYTES;
                    end
                  default:;
                endcase // case (state)
             end 
           
        end
   endgenerate

   always @(posedge clk, posedge reset)
     begin
        if(reset)
          state <= idle;
        else
          case(state)

            idle:
              begin
                 if(buffer_empty)
                   state <= idle;
                 else
                   state <= init_process;
              end

            init_process:
              begin
                 state <= write_process;
              end

            write_process:
              begin
                 if(mem_ready)
                   if(buffer_empty)
                     state <= idle;
                   else
                     state <= init_process;
                 else
                   state <= write_process;
              end

            default:;
          endcase // case (state)
     end // always @ (posedge clk, posedge reset)

   always @*
     begin
        write_empty    = 1'b0;
        buffer_read_en = 1'b0;
        mem_valid      = 1'b0;
        case(state)
          idle:
            write_empty = buffer_empty;
          init_process:
            buffer_read_en = 1'b1; //update buffer's output
          write_process:
            mem_valid = 1'b1;
          default:;
        endcase // case (state)
     end
   
   
   iob_sync_fifo #(
		    .DATA_WIDTH (FE_NBYTES+FE_ADDR_W-BYTES_W+FE_DATA_W),
		    .ADDRESS_WIDTH (WTBUF_DEPTH_W)
		    ) 
   write_throught_buffer 
     (
      .rst     (reset               ),
      .data_out(buffer_dout         ), 
      .empty   (buffer_empty        ),
      .read_en (buffer_read_en      ),
      .clk     (clk                 ),    
      .data_in (buffer_din          ), 
      .full    (buffer_full         ),
      .write_en((|wstrb) && write_en)
      );

endmodule



/*----------------*/
/* Memory Section */
/*----------------*/
//Module that contains all the memories as well as the replacement policies in case necessary

module memory_section 
  #(
    //memory cache's parameters
    parameter FE_ADDR_W   = 32,       //Address width - width that will used for the cache 
    parameter FE_DATA_W   = 32,       //Data width - word size used for the cache
    parameter N_WAYS   = 1,        //Number of Cache Ways
    parameter LINE_OFF_W  = 6,      //Line-Offset Width - 2**NLINE_W total cache lines
    parameter WORD_OFF_W = 3,       //Word-Offset Width - 2**OFFSET_W total FE_DATA_W words per line 
    //Do NOT change - memory cache's parameters - dependency
    parameter NWAY_W   = $clog2(N_WAYS), //Cache Ways Width
    parameter FE_NBYTES  = FE_DATA_W/8,      //Number of Bytes per Word
    parameter BYTES_W = $clog2(FE_NBYTES), //Offset of the Number of Bytes per Word
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    //Do NOT change - slave parameters - dependency
    parameter LINE2MEM_DATA_RATIO_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W), //burst offset based on the cache and memory word size
    //Replacement policy (N_WAYS > 1)
    parameter REP_POLICY = `LRU //LRU - Least Recently Used (stack/shift); LRU_add (1) - LRU with adders ; BIT_PLRU (2) - bit-based pseudoLRU; TREE_PLRU (3) - tree-based pseudoLRU
    )
   ( 
     //master interface
     input                                 clk,
     input                                 reset,
     input [FE_ADDR_W-1:$clog2(FE_NBYTES)] addr,
     input [FE_DATA_W-1:0]                 wdata,
     input [FE_NBYTES-1:0]                 wstrb,
     output [FE_DATA_W-1:0]                rdata,
     input                                 valid,
     //slave interface
     input [BE_DATA_W-1:0]                 line_load_data,
     //
     input                                 line_load, //process of loading the cache-line
     input                                 line_load_en, //enable for during a cache line load
     input [LINE2MEM_DATA_RATIO_W-1:0]     word_counter, //selects the cache-line words elligible to be written
     output                                hit, //cache-hit(1), cache-miss(0)
     input                                 write_en, //global enable
     input                                 invalidate   //invalidate entire cache
     );
   
   localparam TAG_W = FE_ADDR_W - (BYTES_W+WORD_OFF_W+LINE_OFF_W);

   wire [N_WAYS-1:0]                       way_hit, v, way_select;
   wire [N_WAYS*TAG_W-1:0]                 tag;
   assign hit = |way_hit;
   
   wire [N_WAYS*(2**WORD_OFF_W)*FE_DATA_W-1:0] line_rdata;
   wire [LINE_OFF_W-1:0]                       line_addr = addr[BYTES_W + WORD_OFF_W +: LINE_OFF_W];
   wire [TAG_W-1:0]                            line_tag  = addr[         FE_ADDR_W-1 -: TAG_W     ];
   wire [WORD_OFF_W-1:0]                       line_word_select = addr[      BYTES_W +: WORD_OFF_W];
   reg [N_WAYS*(2**WORD_OFF_W)*FE_NBYTES-1:0]  line_wstrb;
   
   
   genvar                                      i,j,k;
   generate
      if (LINE2MEM_DATA_RATIO_W > 0)
        begin
           if(N_WAYS != 1)
             begin
                wire [NWAY_W-1:0] way_hit_bin, way_select_bin;//reason for the 2 generates for single vs multiple ways
                
                
                replacement_process #(
	                              .N_WAYS    (N_WAYS    ),
	                              .LINE_OFF_W(LINE_OFF_W),
                                      .REP_POLICY(REP_POLICY)
	                              )
                replacement_policy_algorithm
                  (
                   .clk       (clk             ),
                   .reset     (reset|invalidate),
                   .write_en  (write_en        ),
                   .way_hit   (way_hit         ),
                   .line_addr (line_addr       ),
                   .way_select(way_select      ),
                   .way_select_bin(way_select_bin)
                   );
                
                onehot_to_bin #(
                                .BIN_W (NWAY_W)
                                ) 
                way_hit_encoder
                  (
                   .onehot(way_hit[N_WAYS-1:1]),
                   .bin   (way_hit_bin)
                   );

                
                //Read Data Multiplexer
                assign rdata [FE_DATA_W-1:0] = line_rdata >> FE_DATA_W*(line_word_select + (2**WORD_OFF_W)*way_hit_bin);
                
                
                //Cache Line Write Strobe Shifter
                always @*
                  if(line_load)
                    line_wstrb = {BE_NBYTES{line_load_en}} << (word_counter*BE_NBYTES + way_select_bin*(2**WORD_OFF_W)*FE_NBYTES);
                  else
                    line_wstrb = (wstrb & {FE_NBYTES{write_en}} & {FE_NBYTES{|way_hit}}) << (line_word_select*FE_NBYTES + way_hit_bin*(2**WORD_OFF_W)*FE_NBYTES);
                
                for (k = 0; k < N_WAYS; k=k+1)
                  begin : line_way
                     for(j = 0; j < 2**LINE2MEM_DATA_RATIO_W; j=j+1)
                       begin : line_word_number
                          for(i = 0; i < BE_DATA_W/FE_DATA_W; i=i+1)
                            begin : line_word_width
                               iob_gen_sp_ram
                                  #(
                                    .DATA_W(FE_DATA_W),
                                    .ADDR_W(LINE_OFF_W)
                                    )
                               cache_memory 
                                  (
                                   .clk (clk),
                                   .en  (~reset), 
                                   .we(line_wstrb[(k*(2**WORD_OFF_W)+j*(BE_DATA_W/FE_DATA_W)+i)*FE_NBYTES +: FE_NBYTES]),
                                   .addr(line_addr),
                                   .data_in ((line_load)? line_load_data[i*FE_DATA_W +: FE_DATA_W] : wdata),
                                   .data_out(line_rdata[(k*(2**WORD_OFF_W)+j*(BE_DATA_W/FE_DATA_W)+i)*FE_DATA_W +: FE_DATA_W])
                                   );
                            end // for (i = 0; i < 2**WORD_OFF_W; i=i+1)
                       end // for (j = 0; j < 2**LINE2MEM_DATA_RATIO_W; j=j+1)
                     iob_reg_file
                       #(
                         .ADDR_WIDTH(LINE_OFF_W), 
                         .COL_WIDTH (1),
                         .NUM_COL   (1)
	                 ) 
	             valid_memory 
	               (
	                .clk  (clk                                ),
	                .rst  (reset|invalidate                   ),
	                .wdata(line_load                          ),				       
	                .addr (line_addr                          ),
	                .en   ((way_select[k])? line_load_en : 1'b0),
	                .rdata(v[k]                               )   
	                );

                     iob_sp_ram
                       #(
                         .DATA_W(TAG_W),
                         .ADDR_W(LINE_OFF_W)
                         )
                     tag_memory 
                       (
                        .clk (clk                                ),
                        .en  (~reset                             ), 
                        .we  ((way_select[k])? line_load_en : 1'b0),
                        .addr(line_addr                          ),
                        .data_in (line_tag                       ),
                        .data_out(tag[TAG_W*k +: TAG_W]          )
                        );

                     //Cache hit signal that indicates which way has had the hit
                     assign way_hit[k] = (line_tag == tag[TAG_W*k +: TAG_W]) &&  v[k]; // to reduce UNDEFINES in simulation
                     
                  end // for (k = 0; k < N_WAYS; k=k+1)
                
             end // if (N_WAYS != 1)
           else
             begin   
                
                //Read Data Multiplexer
                assign rdata [FE_DATA_W-1:0] = line_rdata >> FE_DATA_W*(line_word_select);

                //Cache Line Write Strobe Shifter
                always @*
                  if(line_load)
                    line_wstrb = {BE_NBYTES{line_load_en}} << (word_counter*BE_NBYTES);
                  else
                    line_wstrb = (wstrb & {FE_NBYTES{write_en}})  << (line_word_select*FE_NBYTES);


                for(j = 0; j < 2**LINE2MEM_DATA_RATIO_W; j=j+1)
                  begin : line_word_number
                     for(i = 0; i < BE_DATA_W/FE_DATA_W; i=i+1)
                       begin : line_word_width
                          iob_gen_sp_ram 
                             #(
                               .DATA_W(FE_DATA_W),
                               .ADDR_W(LINE_OFF_W)
                               )
                          cache_memory 
                             (
                              .clk (clk),
                              .en  (~reset ),
                              .we  (line_wstrb[(j*(BE_DATA_W/FE_DATA_W)+i)*FE_NBYTES +: FE_NBYTES]), 
                              .addr(line_addr),
                              .data_in ((line_load)? line_load_data[i*FE_DATA_W +: FE_DATA_W] : wdata),
                              .data_out(line_rdata[(j*(BE_DATA_W/FE_DATA_W)+i)*FE_DATA_W +: FE_DATA_W])
                              );
                       end // for (i = 0; i < 2**WORD_OFF_W; i=i+1)
                  end // for (j = 0; j < 2**LINE2MEM_DATA_RATIO_W; j=j+1)  
                iob_reg_file
                  #(
                    .ADDR_WIDTH(LINE_OFF_W), 
                    .COL_WIDTH (1),
                    .NUM_COL   (1)
	            ) 
	        valid_memory 
	          (
	           .clk  (clk             ),
	           .rst  (reset|invalidate),
	           .wdata(line_load       ),				       
	           .addr (line_addr       ),
	           .en   (line_load       ),
	           .rdata(v               )   
	           );

                iob_sp_ram
                  #(
                    .DATA_W(TAG_W),
                    .ADDR_W(LINE_OFF_W)
                    )
                tag_memory 
                  (
                   .clk (clk      ),
                   .en  (~reset   ), 
                   .we  (line_load),
                   .addr(line_addr),
                   .data_in (line_tag ),
                   .data_out(tag      )
                   );

                //Cache hit signal that indicates which way has had the hit
                assign way_hit = (line_tag == tag) & v;
                
             end // else: !if(N_WAYS != 1)         
        end
      else if(N_WAYS != 1)
        begin
           wire [NWAY_W-1:0] way_hit_bin, way_select_bin;//reason for the 2 generates for single vs multiple ways
           
           
           replacement_process #(
	                         .N_WAYS    (N_WAYS    ),
	                         .LINE_OFF_W(LINE_OFF_W),
                                 .REP_POLICY(REP_POLICY)
	                         )
           replacement_policy_algorithm
             (
              .clk       (clk             ),
              .reset     (reset|invalidate),
              .write_en  (write_en        ),
              .way_hit   (way_hit         ),
              .line_addr (line_addr       ),
              .way_select(way_select      ),
              .way_select_bin(way_select_bin)
              );
           
           onehot_to_bin #(
                           .BIN_W (NWAY_W)
                           ) 
           way_hit_encoder
             (
              .onehot(way_hit[N_WAYS-1:1]),
              .bin   (way_hit_bin)
              );

           
           //Read Data Multiplexer
           assign rdata [FE_DATA_W-1:0] = line_rdata >> FE_DATA_W*(line_word_select + (2**WORD_OFF_W)*way_hit_bin);
           
           //Cache Line Write Strobe Shifter
           always @*
             if(line_load)
               line_wstrb = {BE_NBYTES{line_load_en}} << (way_select_bin*(2**WORD_OFF_W)*FE_NBYTES);
             else
               line_wstrb = (wstrb & {FE_NBYTES{write_en}} & {FE_NBYTES{|way_hit}}) << (line_word_select*FE_NBYTES + way_hit_bin*(2**WORD_OFF_W)*FE_NBYTES);

           for (k = 0; k < N_WAYS; k=k+1)
             begin : line_way
                for(j = 0; j < 2**LINE2MEM_DATA_RATIO_W; j=j+1)
                  begin : line_word_number
                     for(i = 0; i < BE_DATA_W/FE_DATA_W; i=i+1)
                       begin : line_word_width
                          iob_gen_sp_ram
                             #(
                               .DATA_W(FE_DATA_W),
                               .ADDR_W(LINE_OFF_W)
                               )
                          cache_memory 
                             (
                              .clk (clk),
                              .en  (~reset), 
                              .we  (line_wstrb[(k*(2**WORD_OFF_W)+j*(BE_DATA_W/FE_DATA_W)+i)*FE_NBYTES +: FE_NBYTES]),
                              .addr(line_addr),
                              .data_in ((line_load)? line_load_data[i*FE_DATA_W +: FE_DATA_W] : wdata),
                              .data_out(line_rdata[(k*(2**WORD_OFF_W)+j*(BE_DATA_W/FE_DATA_W)+i)*FE_DATA_W +: FE_DATA_W])
                              );
                       end // for (i = 0; i < 2**WORD_OFF_W; i=i+1)
                  end // for (j = 0; j < 2**LINE2MEM_DATA_RATIO_W; j=j+1)
                iob_reg_file
                  #(
                    .ADDR_WIDTH(LINE_OFF_W), 
                    .COL_WIDTH (1),
                    .NUM_COL   (1)
	            ) 
	        valid_memory 
	          (
	           .clk  (clk                                ),
	           .rst  (reset|invalidate                   ),
	           .wdata(line_load                          ),				       
	           .addr (line_addr                          ),
	           .en   ((way_select[k])? line_load : 1'b0),
	           .rdata(v[k]                               )   
	           );

                iob_sp_ram
                  #(
                    .DATA_W(TAG_W),
                    .ADDR_W(LINE_OFF_W)
                    )
                tag_memory 
                  (
                   .clk     (clk                                ),
                   .en      (~reset                             ), 
                   .we      ((way_select[k])? line_load : 1'b0),
                   .addr    (line_addr                          ),
                   .data_in (line_tag                           ),
                   .data_out(tag[TAG_W*k +: TAG_W]              )
                   );

                //Cache hit signal that indicates which way has had the hit
                assign way_hit[k] = (line_tag == tag[TAG_W*k +: TAG_W]) &&  v[k]; // to reduce UNDEFINES in simulation
                
             end // for (k = 0; k < N_WAYS; k=k+1)
           
        end // if (N_WAYS != 1)
      else
        begin   
           
           //Read Data Multiplexer
           assign rdata [FE_DATA_W-1:0] = line_rdata >> FE_DATA_W*(line_word_select);

           //Cache Line Write Strobe Shifter
           always @*
             if(line_load)
               line_wstrb = {BE_NBYTES{line_load_en}};
             else
               line_wstrb = (wstrb & {FE_NBYTES{write_en}}) << (line_word_select*FE_NBYTES);

           for(j = 0; j < 2**LINE2MEM_DATA_RATIO_W; j=j+1)
             begin : line_word_number
                for(i = 0; i < BE_DATA_W/FE_DATA_W; i=i+1)
                  begin : line_word_width
                     iob_gen_sp_ram
                        #(
                          .DATA_W(FE_DATA_W),   
                          .ADDR_W(LINE_OFF_W)
                          )
                     cache_memory 
                        (
                         .clk (clk),
                         .en  (~reset),
                         .we  (line_wstrb[(j*(BE_DATA_W/FE_DATA_W)+i)*FE_NBYTES +: FE_NBYTES]), 
                         .addr(line_addr),
                         .data_in ((line_load)? line_load_data[i*FE_DATA_W +: FE_DATA_W] : wdata),
                         .data_out(line_rdata[(j*(BE_DATA_W/FE_DATA_W)+i)*FE_DATA_W +: FE_DATA_W])
                         );
                  end // for (i = 0; i < 2**WORD_OFF_W; i=i+1)
             end // for (j = 0; j < 2**LINE2MEM_DATA_RATIO_W; j=j+1)  
           iob_reg_file
             #(
               .ADDR_WIDTH(LINE_OFF_W), 
               .COL_WIDTH (1),
               .NUM_COL   (1)
	       ) 
           valid_memory 
             (
	      .clk  (clk             ),
	      .rst  (reset|invalidate),
	      .wdata(line_load       ),				       
	      .addr (line_addr       ),
	      .en   (line_load       ),
	      .rdata(v               )   
	      );

           iob_sp_ram
             #(
               .DATA_W(TAG_W),
               .ADDR_W(LINE_OFF_W)
               )
           tag_memory 
             (
              .clk     (clk      ),
              .en      (~reset   ), 
              .we      (line_load),
              .addr    (line_addr),
              .data_in (line_tag ),
              .data_out(tag      )
              );

           //Cache hit signal that indicates which way has had the hit
           assign way_hit = (line_tag == tag) & v;
           
        end
   endgenerate
endmodule // memory_section



/*---------------------------*/
/* One-Hot to Binary Encoder */
/*---------------------------*/

// One-hot to binary encoder (if input is (0)0 or (0)1, the output is 0)
module onehot_to_bin 
  #(
    parameter BIN_W = 2
    )
   (
    input [2**BIN_W-1:1]   onehot,
    output reg [BIN_W-1:0] bin 
    );
   always @ (onehot) begin: onehot_to_binary_encoder
      integer i;
      reg [BIN_W-1:0] bin_cnt ;
      bin_cnt = 0;
      for (i=1; i<2**BIN_W; i=i+1)
        if (onehot[i]) bin_cnt = bin_cnt|i;
      bin = bin_cnt;    
   end
endmodule  // onehot_to_bin



/*--------------------*/
/* Replacement Policy */
/*--------------------*/
// Module that contains all iob-cache's replacement policies

module replacement_process 
  #(
    parameter N_WAYS     = 16,
    parameter LINE_OFF_W = 0,
    parameter NWAY_W = $clog2(N_WAYS),
    parameter REP_POLICY = `TREE_PLRU //LRU - Least Recently Used; LRU_sh (LRU that uses shifts as a stack) ; BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    )
   (
    input                  clk,
    input                  reset,
    input                  write_en,
    input [N_WAYS-1:0]     way_hit,
    input [LINE_OFF_W-1:0] line_addr,
    output [N_WAYS-1:0]    way_select,
    output [NWAY_W-1:0]    way_select_bin 
    );


   genvar                  i, j, k;

   generate
      if (REP_POLICY == `LRU)
        begin
           
           wire [N_WAYS*NWAY_W -1:0] mru_output, mru_input;
           wire [N_WAYS*NWAY_W -1:0] mru_init; //Initial MRU values of the LRU algorithm, also initialized them in case it's the first access or was invalidated
           wire [N_WAYS*NWAY_W -1:0] mru_cnt; //updates the MRU line, the way used will be the highest value, while the others are decremented
           wire [NWAY_W -1:0]        mru_hit_val [N_WAYS :0]; //Value of the MRU way
           wire [N_WAYS -1:0]        lru_sel; //LRU way, selected form the one with the lowest MRU value
           assign mru_hit_val [0] [NWAY_W -1:0] = {NWAY_W{1'b0}}; //
           
           for (i = 0; i < N_WAYS; i=i+1)
	     begin : lru_counter_algorithm
	        assign mru_init [i*NWAY_W +: NWAY_W] = (|mru_output)? mru_output [i*NWAY_W +: NWAY_W] : i; //verifies if the mru line has been initialized (if any bit in mru_output is HIGH), otherwise applies the priority values
                assign mru_hit_val [i+1][NWAY_W -1:0]  = mru_hit_val[i][NWAY_W-1:0] | ({NWAY_W{way_hit[i]}} & mru_init[(i+1)*NWAY_W -1: i*NWAY_W]); //stores the value of the MRU way
                assign mru_cnt [i*NWAY_W +: NWAY_W] = (way_hit[i])? {NWAY_W{1'b1}} : (mru_init [i*NWAY_W +: NWAY_W] > mru_hit_val [N_WAYS]) ? mru_init [i*NWAY_W +: NWAY_W] - 1 : mru_init [i*NWAY_W +: NWAY_W];// the MRU way gets updated to the the highest value; the remaining, if their value was bigger than the MRU previous value, they get decremented

                assign lru_sel [i] = ~(|mru_init[i*NWAY_W +: NWAY_W]); //selects the way that has the lowest priority (mru_init = 0)              
             end
           
           assign way_select = lru_sel;
           
           assign mru_input = (|way_hit)? mru_cnt : mru_output; //If an hit occured, then it updates, to avoid updating during a write-miss
           
           //Selects the least recent used way (encoder for one-hot to binary format)
           onehot_to_bin #(
                           .BIN_W (NWAY_W)	       
                           ) 
           lru_select
             (    
                  .onehot(lru_sel[N_WAYS-1:1]),
                  .bin(way_select_bin)
                  );

           
           //Most Recently Used (MRU) memory	   
           iob_reg_file
             #(
               .ADDR_WIDTH (LINE_OFF_W),		
               .COL_WIDTH (N_WAYS*NWAY_W),
               .NUM_COL (1)
               ) 
           mru_memory //simply uses the same format as valid memory
             (
              .clk  (clk          ),
              .rst  (reset        ),
              .wdata(mru_input    ),
              .rdata(mru_output   ),			             
              .addr (line_addr    ),
              .en   (write_en     )
              );
           
        end // if (REP_POLICU == `LRU)
      else if(REP_POLICY == `LRU_sh)
        begin

           wire [NWAY_W-1:0] way_hit_bin;
           wire [N_WAYS-1:0] shift_en;                 
           wire [N_WAYS*NWAY_W -1:0] mru_output, mru_input;
           wire [N_WAYS*NWAY_W -1:0] mru_init;
           wire [N_WAYS*NWAY_W -1:0] mru_shift[N_WAYS-1:0];           
           wire [NWAY_W-1:0]         lru;
           
           
           for (i=0; i < N_WAYS; i = i+1)
             begin: mru_init_position_check
                assign mru_init [i*NWAY_W +: NWAY_W] = (|mru_output)? mru_output [i*NWAY_W +: NWAY_W] : i; //verifies if the mru line has been initialized (if any bit in mru_output is HIGH), otherwise applies the priority values, where the lower way line_addres are the least recent (lesser priority)
             end
           
           //Selects the least recent used way (encoder for one-hot to binary format)
           onehot_to_bin #(
                           .BIN_W (NWAY_W)	       
                           ) 
           hit_binary
             (      
                    .onehot(way_hit[N_WAYS-1:1]),
                    .bin(way_hit_bin)
                    );


           for (i=0; i < N_WAYS; i = i+1)
             begin: shift_enabler
                assign shift_en [i] = (mru_init[i*NWAY_W +: NWAY_W] == way_hit_bin); //checks the position of the hit
             end

           
           assign mru_shift[0] = mru_init;
           assign mru_shift[1] = (shift_en[0])? {{NWAY_W{1'b0}}, mru_shift[0][N_WAYS*NWAY_W-1:NWAY_W]} : mru_shift[0];
           for (i = 2; i < N_WAYS; i = i+1)
             begin: priority_shifts
                assign mru_shift[i] = (shift_en[i-1])? { {NWAY_W{1'b0}}, mru_shift[i-1][N_WAYS*NWAY_W -1:(i)*NWAY_W], mru_shift[i-1][(i-1)*NWAY_W -1:0]} : mru_shift[i-1];
             end

           assign mru_input = {mru_shift[N_WAYS-1][N_WAYS*NWAY_W -1-: NWAY_W] | way_hit_bin,  mru_shift[N_WAYS-1][(N_WAYS-1)*NWAY_W-1 :0]}; //makes an OR of the MRU with the Way_hit_bin
           
           assign lru = mru_output[0 +: NWAY_W];
           assign way_select_bin =  lru;//binary
           assign way_select = 1 << lru;//one-hot
           
           //Most Recently Used (MRU) memory	   
           iob_reg_file
             #(
               .ADDR_WIDTH (LINE_OFF_W),		
               .COL_WIDTH (N_WAYS*NWAY_W),
               .NUM_COL (1)
               ) 
           mru_memory //simply uses the same format as valid memory
             (
              .clk  (clk          ),
              .rst  (reset        ),
              .wdata(mru_input    ),
              .rdata(mru_output   ),			             
              .addr (line_addr    ),
              .en   (write_en     )
              );
           
           
        end // if (REP_POLICY == `LRU_sh)
      else if (REP_POLICY == `BIT_PLRU)
        begin

           wire [N_WAYS -1:0]      mru_output;
           wire [N_WAYS -1:0]      mru_input = (&(mru_output | way_hit))? {N_WAYS{1'b0}} : mru_output | way_hit; //When the cache access results in a hit (or access (wish would be 1 in way_hit even during a read-miss), it will add to the MRU, if after the the OR with Way_hit, the entire input is 1s, it resets
           wire [N_WAYS -1:0]      bitplru; //least recent used 
           
           assign bitplru[0] = ~mru_output[0];

           for (i = 1; i < N_WAYS; i=i+1)
	     begin : bitplru_priority
                assign bitplru [i] = ~mru_output[i] & (&mru_output[i-1:0]); //verifies priority (lower index)
             end  


           assign way_select = bitplru;
           
           //Selects the least recent used way (encoder for one-hot to binary format)
           onehot_to_bin #(
                           .BIN_W (NWAY_W)	       
                           ) 
           lru_select
             (      
                    .onehot(bitplru[N_WAYS-1:1]),
                    .bin(way_select_bin)
                    );

           
           //Most Recently Used (MRU) memory	   
           iob_reg_file
             #(
               .ADDR_WIDTH (LINE_OFF_W),
               .COL_WIDTH (N_WAYS),
               .NUM_COL (1)
               ) 
           mru_memory //simply uses the same format as valid memory
             (
              .clk  (clk          ),
              .rst  (reset        ),
              .wdata(mru_input    ),
              .rdata(mru_output   ),			            
              .addr (line_addr    ),
              .en   (write_en     )
              );

           
        end // if (REP_POLICY == BIT_PLRU)
      else // (REP_POLICY == TREE_PLRU)
        begin
           
           wire [N_WAYS -1: 1] t_plru, t_plru_output;
           wire [N_WAYS -1: 0] nway_tree [NWAY_W: 0]; // the order of the way line_addr will be [lower; ...; higher way line_addr], for readable reasons
           wire [N_WAYS -1: 0] tplru_sel;
           
           // Tree-structure: t_plru[i] = tree's bit i (0 - top, towards bottom of the tree)
           for (i = 1; i <= NWAY_W; i = i + 1)
	     begin : tree_bit
	        for (j = 0; j < (1<<(i-1)) ; j = j + 1)
	          begin : tree_structure
		     assign t_plru [(1<<(i-1))+j] = (t_plru_output[(1<<(i-1))+j] && (~(|way_hit[(N_WAYS-(2*j+1)*(N_WAYS>>i)) -1: N_WAYS-(2*j+2)*(N_WAYS>>i)]))) || (|way_hit[N_WAYS-(2*j*(N_WAYS>>i)) -1: N_WAYS-(2*j+1)*(N_WAYS>>i)]); // (t-bit * (~|way_hit[lower_section]) + |way_hit[top_section])
	          end
	     end
           
           // Tree's Encoder (to translate it into selectable way) -- nway_tree will represent the line_addres of the way to be selected, but it's order is inverted to be more readable (check treeplru_sel)
           assign nway_tree [0] = {N_WAYS{1'b1}}; // the first position of the tree's matrix will be all 1s, for the AND logic of the following algorithm work properlly
           for (i = 1; i <= NWAY_W; i = i + 1)
	     begin : encoder_bit
	        for (j = 0; j < (1 << (i-1)); j = j + 1)
	          begin :  encoder_microposition
		     for (k = 0; k < (N_WAYS >> i); k = k + 1)
		       begin : encoder_macroposition
		          assign nway_tree [i][j*(N_WAYS >> (i-1)) + k] = nway_tree [i-1][j*(N_WAYS >> (i-1)) + k] && ~(t_plru_output [(1 << (i-1)) + j]); // the first half will be the Tree's bit inverted (0 equal Left (upper position)
		          assign nway_tree [i][j*(N_WAYS >> (i-1)) + k + (N_WAYS >> i)] = nway_tree [i-1][j*(N_WAYS >> (i-1)) + k] && t_plru_output [(1 << (i-1)) + j]; //second half of the same Tree's bit (1 equals Right (lower position))
		       end	
	          end
	     end 
           // placing the way select wire in the correct order for the onehot-binary encoder
           for (i = 0; i < N_WAYS; i = i + 1)
	     begin : way_selector
	        assign tplru_sel[i] = nway_tree [NWAY_W][N_WAYS - i -1];//the last row of nway_tree has the result of the Tree's encoder
	     end


           assign way_select = tplru_sel;
           
           //Selects the least recent used way (encoder for one-hot to binary format)
           onehot_to_bin #(
                           .BIN_W (NWAY_W)	       
                           ) 
           lru_select
             (
              .onehot(tplru_sel[N_WAYS-1:1]),
              .bin(way_select_bin)
              );

           
           //Most Recently Used (MRU) memory	   
           iob_reg_file
             #(
               .ADDR_WIDTH (LINE_OFF_W),
               .COL_WIDTH (N_WAYS-1),
               .NUM_COL (1)
               ) 
           mru_memory //simply uses the same format as valid memory
             (
              .clk  (clk          ),
              .rst  (reset        ),
              .wdata(t_plru       ),
              .rdata(t_plru_output),     
              .addr (line_addr    ),
              .en   (write_en     )
              );
           
        end // else: !if(REP_POLICY == BIT_PLRU)
   endgenerate

endmodule



/*------------------*/
/* Cache Controller */
/*------------------*/
//Module responsible for performance measuring, information about the current cache state, and other cache functions (like cache-invalidate)

module cache_controller #(
                          parameter FE_DATA_W = 32,
                          parameter CTRL_CNT = 1
                          )
   (
    input                       clk,
    input [`CTRL_COUNTER_W-1:0] din, 
    output reg                  invalidate,
    input [`CTRL_ADDR_W-1:0]    addr,
    output reg [FE_DATA_W-1:0]  dout,
    input                       valid,
    output reg                  ready,
    input                       reset, 
    input [1:0]                 write_state
    );

   generate
      if(CTRL_CNT)
        begin
           
           reg [FE_DATA_W-1:0]             read_hit_cnt, read_miss_cnt, write_hit_cnt, write_miss_cnt;
           reg [FE_DATA_W-1:0]             hit_cnt, miss_cnt;
           reg                             ctrl_counter_reset;

           wire                            ctrl_arst = reset| ctrl_counter_reset;
           
           always @ (posedge clk, posedge ctrl_arst)
             begin 		
	        if (ctrl_arst) 
	          begin
                     hit_cnt  <= {FE_DATA_W{1'b0}};
	             miss_cnt <= {FE_DATA_W{1'b0}};
                     read_hit_cnt  <= {FE_DATA_W{1'b0}};
	             read_miss_cnt <= {FE_DATA_W{1'b0}};
	             write_hit_cnt  <= {FE_DATA_W{1'b0}};
	             write_miss_cnt <= {FE_DATA_W{1'b0}};
                  end 
	        else
	          begin
                     if (din == `READ_HIT)
	               begin
		          read_hit_cnt <= read_hit_cnt + 1;
		          hit_cnt <= hit_cnt + 1;	  
	               end
	             else if (din == `WRITE_HIT)
	               begin
		          write_hit_cnt <= write_hit_cnt + 1;
		          hit_cnt <= hit_cnt + 1;
	               end
	             else if (din == `READ_MISS)
	               begin
		          read_miss_cnt <= read_miss_cnt + 1;
		          miss_cnt <= miss_cnt + 1;
	               end
	             else if (din == `WRITE_MISS)
	               begin
		          write_miss_cnt <= write_miss_cnt + 1;
		          miss_cnt <= miss_cnt + 1;
	               end
	             else
	               begin
		          read_hit_cnt <= read_hit_cnt;
		          read_miss_cnt <= read_miss_cnt;
		          write_hit_cnt <= write_hit_cnt;
		          write_miss_cnt <= write_miss_cnt;
		          hit_cnt <= hit_cnt;
		          miss_cnt <= miss_cnt;
	               end
	          end // else: !if(ctrl_arst)   
             end // always @ (posedge clk, posedge ctrl_arst)
           
           always @ (posedge clk)
             begin
	        dout <= {FE_DATA_W{1'b0}};
	        invalidate <= 1'b0;
	        ctrl_counter_reset <= 1'b0;
	        ready <= valid; // Sends acknowlege the next clock cycle after request (handshake)               
	        if(valid)
                  if (addr == `ADDR_CACHE_HIT)
	            dout <= hit_cnt;
                  else if (addr == `ADDR_CACHE_MISS)
	            dout <= miss_cnt;
	          else if (addr == `ADDR_CACHE_READ_HIT)
	            dout <= read_hit_cnt;
	          else if (addr == `ADDR_CACHE_READ_MISS)
	            dout <= read_miss_cnt;
	          else if (addr == `ADDR_CACHE_WRITE_HIT)
	            dout <= write_hit_cnt;
	          else if (addr == `ADDR_CACHE_WRITE_MISS)
	            dout <= write_miss_cnt;
	          else if (addr == `ADDR_RESET_COUNTER)
	            ctrl_counter_reset <= 1'b1;
	          else if (addr == `ADDR_CACHE_INVALIDATE)
	            invalidate <= 1'b1;	
	          else if (addr == `ADDR_BUFFER_EMPTY)
                    dout <= write_state[0];
                  else if (addr == `ADDR_BUFFER_FULL)
                    dout <= write_state[1];   
             end // always @ (posedge clk)
        end // if (CTRL_CNT)
      else
        begin
           
           always @ (posedge clk)
             begin
	        dout <= {FE_DATA_W{1'b0}};
	        invalidate <= 1'b0;
	        ready <= valid; // Sends acknowlege the next clock cycle after request (handshake)               
	        if(valid)
	          if (addr == `ADDR_CACHE_INVALIDATE)
	            invalidate <= 1'b1;	
	          else if (addr == `ADDR_BUFFER_EMPTY)
                    dout <= write_state[0];
                  else if (addr == `ADDR_BUFFER_FULL)
                    dout <= write_state[1];         
             end // always @ (posedge clk)
        end // else: !if(CTRL_CNT)  
   endgenerate                
   
endmodule // cache_controller


module iob_gen_sp_ram #(
                        parameter DATA_W = 32,
                        parameter ADDR_W = 10
                        )  
   (                
                    input                clk,
                    input                en, 
                    input [DATA_W/8-1:0] we, 
                    input [ADDR_W-1:0]   addr,
                    output [DATA_W-1:0]  data_out,
                    input [DATA_W-1:0]   data_in
                    );

   genvar                                i;
   generate
      for (i = 0; i < (DATA_W/8); i = i + 1)
        begin : ram
           iob_sp_ram
               #(
                 .DATA_W(8),
                 .ADDR_W(ADDR_W)
                 )
           iob_cache_mem
               (
                .clk (clk),
                .en  (en),
                .we  (we[i]),
                .addr(addr),
                .data_out(data_out[8*i +: 8]),
                .data_in (data_in [8*i +: 8])
                );
        end
   endgenerate

endmodule // iob_gen_sp_ram
