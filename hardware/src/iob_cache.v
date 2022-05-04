`timescale 1ns / 1ps
`include "iob_lib.vh"
`include "iob-cache.vh"

///////////////
// IOb-cache //
///////////////

module iob_cache 
  #(
    //memory cache's parameters
    parameter FE_ADDR_W = 32,  //PARAM & ? & ? & Address width - width of the Master's entire access address (including the LSBs that are discarded, but discarding the Controller's)
    parameter FE_DATA_W = 32,   //PARAM & ? & ? & Data width - word size used for the cache
    parameter N_WAYS = 2,      //PARAM & ? & ? & Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter LINE_OFF_W = 7,    //PARAM & ? & ? & Line-Offset Width - 2**NLINE_W total cache lines
    parameter WORD_OFF_W = 3,    //PARAM & ? & ? & Word-Offset Width - 2**OFFSET_W total FE_DATA_W words per line - WARNING about LINE2MEM_W (can cause word_counter [-1:0]
    parameter WTBUF_DEPTH_W = 5,   //PARAM & ? & ? & Depth Width of Write-Through Buffer
    //Replacement policy (N_WAYS > 1)
    parameter REP_POLICY = `PLRU_mru, //MACRO & ? & ? & LRU - Least Recently Used; PLRU_mru (1) - mru-based pseudoLRU; PLRU_tree (3) - tree-based pseudoLRU 
    //Do NOT change - memory cache's parameters - dependency
    parameter NWAY_W = $clog2(N_WAYS),  //PARAM & ? & ? & Cache Ways Width
    parameter FE_NBYTES = FE_DATA_W/8,       //PARAM & ? & ? & Number of Bytes per Word
    parameter FE_BYTE_W = $clog2(FE_NBYTES), //PARAM & ? & ? & Byte Offset
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //PARAM & ? & ? & Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //PARAM & ? & ? & Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //PARAM & ? & ? & Number of bytes
    parameter BE_BYTE_W = $clog2(BE_NBYTES), //PARAM & ? & ? & Offset of Number of Bytes
    //Cache-Memory base Offset
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W),  //PARAM & ? & ? & Logarithm Ratio between the size of the cache-line and the BE's data width 
    /*---------------------------------------------------*/
    //Write Policy 
    parameter WRITE_POL = `WRITE_THROUGH, //MACRO & ? & ? & write policy: write-through (0), write-back (1)
    /*---------------------------------------------------*/
    //Controller's options
    parameter CTRL_CACHE = 0, //PARAM & ? & ? & Adds a Controller to the cache, to use functions sent by the master or count the hits and misses
    parameter CTRL_CNT = 0    //PARAM & ? & ? & Counters for Cache Hits and Misses - Disabling this and previous, the Controller only store the buffer states and allows cache invalidation
    ) 
   (
    //START_IO_TABLE gen
    `IOB_INPUT(clk,1),   //System clock input
    `IOB_INPUT(reset,1), //System reset, asynchronous and active high

    //Master i/f
    //START_IO_TABLE iob_m
    `IOB_INPUT(valid, 1),          //Native CPU interface valid signal
`ifdef WORD_ADDR   
    `IOB_INPUT(addr,CTRL_CACHE + FE_ADDR_W - FE_BYTE_W), //Native CPU interface address signal
`else
    `IOB_INPUT(addr,CTRL_CACHE + FE_ADDR_W), //Native CPU interface address signal
`endif
    `IOB_INPUT(wdata,FE_DATA_W),   //Native CPU interface data write signal
    `IOB_INPUT(wstrb,FE_NBYTES),   //Native CPU interface write strobe signal
    `IOB_OUTPUT(rdata, FE_DATA_W), //Native CPU interface read data signal
    `IOB_OUTPUT(ready,1),          //Native CPU interface ready signal
`ifdef CTRL_IO
    //control-status io
    //START_IO_TABLE cs_io
    `IOB_INPUT(force_inv_in,1),     //force 1'b0 if unused
    `IOB_OUTPUT(force_inv_out,1),   //cache invalidate signal
    `IOB_INPUT(wtb_empty_in,1),     //force 1'b1 if unused
    `IOB_OUTPUT(wtb_empty_out,1),   //write-through buffer empty signal
`endif  
    //Slave i/f - Native
    //START_IO_TABLE iob_s
    `IOB_OUTPUT(mem_valid,1),         //Native CPU interface valid signal
    `IOB_OUTPUT(mem_addr,BE_ADDR_W),  //Native CPU interface address signal
    `IOB_OUTPUT(mem_wdata,BE_DATA_W), //Native CPU interface data write signal
    `IOB_OUTPUT(mem_wstrb,BE_NBYTES), //Native CPU interface write strobe signal
    `IOB_INPUT(mem_rdata,BE_DATA_W),  //Native CPU interface read data signal
    `IOB_INPUT(mem_ready,1)           //Native CPU interface ready signal
    );

   
   //internal signals (front-end inputs)
   wire                                         data_valid, data_ready;
   wire [FE_ADDR_W -1:FE_BYTE_W]                data_addr; 
   wire [FE_DATA_W-1 : 0]                       data_wdata, data_rdata;
   wire [FE_NBYTES-1: 0]                        data_wstrb;
   
   //stored signals
   wire [FE_ADDR_W -1:FE_BYTE_W]                data_addr_reg; 
   wire [FE_DATA_W-1 : 0]                       data_wdata_reg;
   wire [FE_NBYTES-1: 0]                        data_wstrb_reg;
   wire                                         data_valid_reg;

   //back-end write-channel
   wire                                         write_valid, write_ready;
   wire [FE_ADDR_W-1:FE_BYTE_W + WRITE_POL*WORD_OFF_W] write_addr;
   wire [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFF_W)-FE_DATA_W)-1 :0] write_wdata;
   wire [FE_NBYTES-1:0]                                write_wstrb;
   
   //back-end read-channel
   wire                                                replace_valid, replace;
   wire [FE_ADDR_W -1:BE_BYTE_W+LINE2MEM_W]            replace_addr; 
   wire                                                read_valid;
   wire [LINE2MEM_W-1:0]                               read_addr;
   wire [BE_DATA_W-1:0]                                read_rdata;
   
   //cache-control
   wire                                                ctrl_valid, ctrl_ready;   
   wire [`CTRL_ADDR_W-1:0]                             ctrl_addr;
   wire                                                wtbuf_full, wtbuf_empty;
   wire                                                write_hit, write_miss, read_hit, read_miss;
   wire [CTRL_CACHE*(FE_DATA_W-1):0]            ctrl_rdata;
   wire                                         invalidate;
   
`ifdef CTRL_IO
   assign force_inv_out = invalidate;

   generate
      if (CTRL_CACHE)
        assign wtb_empty_out = wtbuf_empty;
      else
        assign wtb_empty_out = wtbuf_empty & wtb_empty_in;//to remove unconnected port warning. If unused wtb_empty_in = 1'b1
   endgenerate 
`endif

   //BLOCK Front-end & Front-end block.
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
      .valid (valid),
      .addr  (addr),
      .wdata (wdata),
      .wstrb (wstrb),
      .rdata (rdata),
      .ready (ready),
      //cache-memory input signals
      .data_valid (data_valid),
      .data_addr  (data_addr),
      //cache-memory output
      .data_rdata (data_rdata),
      .data_ready (data_ready),
      //stored input signals
      .data_valid_reg (data_valid_reg),
      .data_addr_reg  (data_addr_reg),
      .data_wdata_reg (data_wdata_reg),
      .data_wstrb_reg (data_wstrb_reg),
      //cache-control
      .ctrl_valid (ctrl_valid),
      .ctrl_addr  (ctrl_addr),
      .ctrl_rdata (ctrl_rdata),
      .ctrl_ready (ctrl_ready)
      );


   //BLOCK Cache memory & Cache memory block.
   cache_memory
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),
       .BE_DATA_W (BE_DATA_W),
       .N_WAYS     (N_WAYS),
       .LINE_OFF_W (LINE_OFF_W),
       .WORD_OFF_W (WORD_OFF_W),
       .REP_POLICY (REP_POLICY),    
       .WTBUF_DEPTH_W (WTBUF_DEPTH_W),
       .CTRL_CACHE(CTRL_CACHE),
       .CTRL_CNT  (CTRL_CNT),
       .WRITE_POL (WRITE_POL)
       )
   cache_memory
     (
      .clk   (clk),
      .reset (reset),
      //front-end
      //internal data signals
      .valid (data_valid),
      .addr  (data_addr[FE_ADDR_W-1:BE_BYTE_W + LINE2MEM_W]),
      //.wdata (data_wdata),
      // .wstrb (data_wstrb),
      .rdata (data_rdata),
      .ready (data_ready),
      //stored data signals
      .valid_reg (data_valid_reg),   
      .addr_reg  (data_addr_reg),
      .wdata_reg (data_wdata_reg),
      .wstrb_reg (data_wstrb_reg),
      //back-end
      //write-through-buffer (write-channel)
      .write_valid (write_valid),
      .write_addr  (write_addr),
      .write_wdata (write_wdata),
      .write_wstrb (write_wstrb),
      .write_ready (write_ready),
      //cache-line replacement (read-channel)
      .replace_valid (replace_valid),
      .replace_addr  (replace_addr),
      .replace (replace),
      .read_valid (read_valid),
      .read_addr  (read_addr),
      .read_rdata (read_rdata),
      //control's signals 
      .wtbuf_empty (wtbuf_empty),
      .wtbuf_full  (wtbuf_full),
      .write_hit   (write_hit),
      .write_miss  (write_miss),
      .read_hit    (read_hit),
      .read_miss   (read_miss),
`ifdef CTRL_IO
      .invalidate  (invalidate | force_inv_in)
`else
      .invalidate  (invalidate)
`endif
      );

   //BLOCK Back-end & Back-end block.
   back_end_native
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),  
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WORD_OFF_W (WORD_OFF_W),
       .WRITE_POL (WRITE_POL)
       )
   back_end
     (
      .clk(clk),
      .reset(reset),
      //write-through-buffer (write-channel)
      .write_valid (write_valid),
      .write_addr  (write_addr),
      .write_wdata (write_wdata),
      .write_wstrb (write_wstrb),
      .write_ready (write_ready),
      //cache-line replacement (read-channel)
      .replace_valid (replace_valid),
      .replace_addr  (replace_addr),
      .replace (replace),
      .read_valid (read_valid),
      .read_addr  (read_addr),
      .read_rdata (read_rdata),
      //back-end native interface
      .mem_valid (mem_valid),
      .mem_addr  (mem_addr),
      .mem_wdata (mem_wdata),
      .mem_wstrb (mem_wstrb),
      .mem_rdata (mem_rdata),
      .mem_ready (mem_ready)  
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
         .clk   (clk),
         .reset (reset),
         //control's signals
         .valid (ctrl_valid),
         .addr  (ctrl_addr),
         //write data
         .wtbuf_full (wtbuf_full),
`ifdef CTRL_IO
         .wtbuf_empty (wtbuf_empty & wtb_empty_in),
`else
         .wtbuf_empty (wtbuf_empty), 
`endif
         .write_hit  (write_hit),
         .write_miss (write_miss),
         .read_hit   (read_hit),
         .read_miss  (read_miss),
         ////////////
         .rdata (ctrl_rdata),
         .ready (ctrl_ready),
         .invalidate (invalidate)
         );
      else
        begin
           assign ctrl_rdata = 1'bx;
           assign ctrl_ready = 1'bx;
           assign invalidate = 1'b0;
        end // else: !if(CTRL_CACHE)
      
   endgenerate

endmodule // iob_cache   
