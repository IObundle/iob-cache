`timescale 1ns/1ps
`include "iob-cache.vh"
///////////
// Wrapper:
///////////////////////////////////////////////////////////////
//  L2 cache connected to an L1 Instruction and Data caches  //
//     Master single-port, instr port selects L1 caches      //                      
///////////////////////////////////////////////////////////////


module L2_ID_1sp
  #(
    //Universal parameters -- faster configuration
    parameter FE_ADDR_W = 32,       //Address width - width that will used for the cache - every cache's front-end
    parameter FE_DATA_W = 32,       //Data width - word size used for the cache          - every cache's front-end
    parameter BE_DATA_W = 32,   //Data width of the memory                           - L2's  back-end
    parameter BE_ADDR_W = 32,   //Address width of the higher hierarchy memory       - L2's  back-end
    parameter AXI_INTERF = 1,    //Back-End Memory interface (1 - AXI, 0 - Native)
    parameter REP_POLICY = `LRU, //LRU - Least Recently Used (0); BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU - caches' replacement policy (mostly for L2)
    parameter LA_INTERF = 0,    //Look-ahead Interface - Store Front-End input signal
    parameter CTRL_CNT = 1,    
  
    // L1 - General parameters
    parameter L1_ADDR_W = FE_ADDR_W,   //Address width - width that will used for the cache 
    parameter L1_DATA_W = FE_DATA_W,   //Data width - word size used for the cache
    parameter L1_N_WAYS = 1,        //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter L1_LINE_OFF_W = 3,    //Line-Offset Width - 2**NLINE_W total cache lines
    parameter L1_WORD_OFF_W = 2,    //Word-Offset Width - 2**OFFSET_W total DATA_W words per line
    parameter L1_WTBUF_DEPTH_W = 4, //Depth Width of Write-Through Buffer
    parameter L1_REP_POLICY = REP_POLICY, //LRU - Least Recently Used (0); BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU (if N_WAYS = 1, this parameter will be ignored)
  
    ///////////////////
    // L2 parameters //
    ///////////////////
    //Front-End L2 parameters will be equal from the L1 Back-End's
    parameter L2_ADDR_W   = FE_ADDR_W,   //Address width - width that will used for the cache 
    parameter L2_DATA_W   = FE_DATA_W,   //Data width - word size used for the cache
    parameter L2_N_WAYS   = 4,        //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter L2_LINE_OFF_W  = 3,     //Line-Offset Width - 2**NLINE_W total cache lines
    parameter L2_WORD_OFF_W = 4,      //Word-Offset Width - 2**OFFSET_W total DATA_W words per line - WARNING about MEM_OFFSET_W (can cause word_counter [-1:0] if the cache line is equal or less than the Data width in the back-end
    parameter L2_WTBUF_DEPTH_W = 4,   //Depth Width of Write-Through Buffer
    //Replacement policy (N_WAYS > 1)
    parameter L2_REP_POLICY = REP_POLICY, //LRU - Least Recently Used (0); BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    //Back-End L2 parameters - Higher hierarchy memory (slave) interface parameters
    parameter L2_MEM_ADDR_W = BE_ADDR_W, //Address width of the higher hierarchy memory
    parameter L2_MEM_DATA_W = BE_DATA_W, //Data width of the memory 
    //AXI specific parameters
    parameter L2_AXI_ID_W                 = 1, //AXI ID (identification) width
    parameter [L2_AXI_ID_W-1:0] L2_AXI_ID = 0, //AXI ID value
  
    /////////////////////////
    // L1-Instr parameters //
    /////////////////////////
    parameter L1_I_N_WAYS     = L1_N_WAYS,      //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter L1_I_LINE_OFF_W = L1_LINE_OFF_W,  //Line-Offset Width - 2**NLINE_W total cache lines
    parameter L1_I_WORD_OFF_W = L1_WORD_OFF_W,  //Word-Offset Width - 2**OFFSET_W total DATA_W words per line - WARNING about MEM_OFFSET_W (can cause word_counter [-1:0]
    parameter L1_I_WTBUF_DEPTH_W = L1_WTBUF_DEPTH_W,   //Depth Width of Write-Through Buffer
    //Replacement policy (N_WAYS > 1)
    parameter L1_I_REP_POLICY = L1_REP_POLICY, //LRU - Least Recently Used (0); BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    //Look-ahead Interface - Store Front-End input signals
    parameter L1_I_LA_INTERF = LA_INTERF, //default value
    //Controller counters
    parameter L1_I_CTRL_CNT = 0,
    
    ////////////////////////
    // L1-Data parameters //
    ////////////////////////
    parameter L1_D_N_WAYS      = L1_N_WAYS,     //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter L1_D_LINE_OFF_W  = L1_LINE_OFF_W, //Line-Offset Width - 2**NLINE_W total cache lines
    parameter L1_D_WORD_OFF_W  = L1_WORD_OFF_W, //Word-Offset Width - 2**OFFSET_W total DATA_W words per line - WARNING about MEM_OFFSET_W (can cause word_counter [-1:0]
    parameter L1_D_WTBUF_DEPTH_W = L1_WTBUF_DEPTH_W,   //Depth Width of Write-Through Buffer
    //Replacement policy (N_WAYS > 1)
    parameter L1_D_REP_POLICY = L1_REP_POLICY, //LRU - Least Recently Used (0); BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    //Look-ahead Interface - Store Front-End input signals
    parameter L1_D_LA_INTERF = LA_INTERF, //default value
    //Controller counters
    parameter L1_D_CTRL_CNT = CTRL_CNT
    )
   (
    // General ports
    input                        clk,
    input                        reset,
    // L1  ports
    input [L1_ADDR_W :0]         addr, // cache_addr[ADDR_W] (MSB) selects cache (0) or controller (1)
    input [L1_DATA_W-1:0]        wdata,
    input [L1_DATA_W/8-1:0]      wstrb,
    output [L1_DATA_W-1:0]       rdata,
    input                        valid,
    input                        instr,
    output                       ready,
   
    // L2  ports
    // AXI interface 
    // Address Write
    output [L2_AXI_ID_W-1:0]     axi_awid, 
    output [L2_MEM_ADDR_W-1:0]   axi_awaddr,
    output [7:0]                 axi_awlen,
    output [2:0]                 axi_awsize,
    output [1:0]                 axi_awburst,
    output [0:0]                 axi_awlock,
    output [3:0]                 axi_awcache,
    output [2:0]                 axi_awprot,
    output [3:0]                 axi_awqos,
    output                       axi_awvalid,
    input                        axi_awready,
    //Write
    output [L2_MEM_DATA_W-1:0]   axi_wdata,
    output [L2_MEM_DATA_W/8-1:0] axi_wstrb,
    output                       axi_wlast,
    output                       axi_wvalid, 
    input                        axi_wready,
    input [L2_AXI_ID_W-1:0]      axi_bid,
    input [1:0]                  axi_bresp,
    input                        axi_bvalid,
    output                       axi_bready,
    //Address Read
    output [L2_AXI_ID_W-1:0]     axi_arid,
    output [L2_MEM_ADDR_W-1:0]   axi_araddr, 
    output [7:0]                 axi_arlen,
    output [2:0]                 axi_arsize,
    output [1:0]                 axi_arburst,
    output [0:0]                 axi_arlock,
    output [3:0]                 axi_arcache,
    output [2:0]                 axi_arprot,
    output [3:0]                 axi_arqos,
    output                       axi_arvalid, 
    input                        axi_arready,
    //Read
    input [L2_AXI_ID_W-1:0]      axi_rid,
    input [L2_MEM_DATA_W-1:0]    axi_rdata,
    input [1:0]                  axi_rresp,
    input                        axi_rlast, 
    input                        axi_rvalid, 
    output                       axi_rready,
    //Native interface
    output [L2_MEM_ADDR_W :0]    mem_addr,
    output                       mem_valid,
    input                        mem_ready,
    output [L2_MEM_DATA_W-1:0]   mem_wdata,
    output [L2_MEM_DATA_W/8-1:0] mem_wstrb,
    input [L2_MEM_DATA_W-1:0]    mem_rdata
  );
   
   //L1-I
   wire [L2_ADDR_W  :0]          i_mem_addr;
   wire [L2_DATA_W-1:0]          i_mem_wdata, i_mem_rdata;
   wire [L2_DATA_W/8-1:0]        i_mem_wstrb;
   wire                          i_mem_valid, i_mem_ready;
   //L1-D
   wire [L2_MEM_ADDR_W  :0]      d_mem_addr;
   wire [L2_DATA_W-1:0]          d_mem_wdata, d_mem_rdata;
   wire [L2_DATA_W/8-1:0]        d_mem_wstrb;
   wire                          d_mem_valid, d_mem_ready;
   //L2
   wire [L2_ADDR_W  :0]          int_addr;
   wire [L2_DATA_W-1:0]          int_wdata, int_rdata;
   wire [L2_DATA_W/8-1:0]        int_wstrb;
   wire                          int_valid, int_ready;

   //ready signal
   wire                          i_ready, d_ready;
   wire [L1_DATA_W -1 : 0]       i_rdata, d_rdata;
   assign ready = i_ready | d_ready;
   assign rdata = (d_ready)? d_rdata : i_rdata;
   
   

   
   iob_cache #(
               .FE_ADDR_W     (L1_ADDR_W),
               .FE_DATA_W     (L1_DATA_W),
               .N_WAYS     (L1_I_N_WAYS),
               .LINE_OFF_W (L1_I_LINE_OFF_W),
               .WORD_OFF_W (L1_I_WORD_OFF_W),
               .BE_ADDR_W (L2_ADDR_W+1),
               .BE_DATA_W (L2_DATA_W),
               .REP_POLICY (L1_I_REP_POLICY),
               .WTBUF_DEPTH_W (L1_I_WTBUF_DEPTH_W),
               .LA_INTERF     (L1_I_LA_INTERF),
               .CTRL_CNT      (L1_I_CTRL_CNT)
               )
   L1_I
     (
      .clk   (clk),
      .reset (reset),
      .wdata (wdata),
      .addr  (addr ),
      .wstrb (wstrb),
      .rdata (i_rdata),
      .valid (valid & instr),
      .ready (i_ready),
      //
      //       // NATIVE MEMORY INTERFACE
      //
      .mem_addr (i_mem_addr),
      .mem_wdata(i_mem_wdata),
      .mem_wstrb(i_mem_wstrb),
      .mem_rdata(i_mem_rdata),
      .mem_valid(i_mem_valid),
      .mem_ready(i_mem_ready)
      );



   
   iob_cache #(
               .FE_ADDR_W     (L1_ADDR_W),
               .FE_DATA_W     (L1_DATA_W),
               .N_WAYS     (L1_D_N_WAYS),
               .LINE_OFF_W (L1_D_LINE_OFF_W),
               .WORD_OFF_W (L1_D_WORD_OFF_W),
               .BE_ADDR_W (L2_ADDR_W+1),
               .BE_DATA_W (L2_DATA_W),
               .REP_POLICY (L1_D_REP_POLICY),
               .WTBUF_DEPTH_W (L1_D_WTBUF_DEPTH_W),
               .LA_INTERF     (L1_D_LA_INTERF),
               .CTRL_CNT      (L1_D_CTRL_CNT)
               )
   L1_D
     (
      .clk   (clk),
      .reset (reset),
      .wdata (wdata),
      .addr  (addr ),
      .wstrb (wstrb),
      .rdata (d_rdata),
      .valid (valid & (~instr)),
      .ready (d_ready),
      //
      // NATIVE MEMORY INTERFACE
      //
      .mem_addr (d_mem_addr),
      .mem_wdata(d_mem_wdata),
      .mem_wstrb(d_mem_wstrb),
      .mem_rdata(d_mem_rdata),
      .mem_valid(d_mem_valid),
      .mem_ready(d_mem_ready)
      );
   
   /*    
    merge #(
    .N_MASTERS(2)
    )
    cache_inter
    (
    .m_req ({{i_mem_valid, i_mem_addr, i_mem_wdata, i_mem_wstrb},{d_mem_valid, d_mem_addr, d_mem_wdata, d_mem_wstrb}}),
    .m_resp ({{i_mem_ready, i_mem_rdata},{d_mem_ready, d_mem_rdata}}),    
    .s_req ({int_valid, int_addr, int_wdata, int_wstrb}),
    .s_resp ({int_ready, int_rdata})
    );
    */    
   




   //Interconnect - Only temporary until merge is fixed - terrible critical path
   assign int_addr =  (i_mem_valid)? i_mem_addr : d_mem_addr;
   assign int_wdata = (i_mem_valid)? i_mem_wdata : d_mem_wdata;
   assign int_wstrb = (i_mem_valid)? i_mem_wstrb : d_mem_wstrb;
   assign int_valid = i_mem_valid | d_mem_valid;
   assign i_mem_rdata = int_rdata;
   assign d_mem_rdata = int_rdata;
   assign i_mem_ready = int_ready & i_mem_valid;
   assign d_mem_ready = int_ready & d_mem_valid;
   
   

   generate
      if (AXI_INTERF)
        begin

           iob_cache_axi #(
                           .FE_ADDR_W    (L2_ADDR_W),
                           .FE_DATA_W    (L2_DATA_W),
                           .N_WAYS    (L2_N_WAYS),
                           .LINE_OFF_W(L2_LINE_OFF_W),
                           .WORD_OFF_W(L2_WORD_OFF_W),
                           .BE_ADDR_W(L2_MEM_ADDR_W),
                           .BE_DATA_W(L2_MEM_DATA_W),
                           .REP_POLICY(L2_REP_POLICY),
                           .WTBUF_DEPTH_W (L2_WTBUF_DEPTH_W),
                           .CTRL_CNT (0)
                           )
           L2 
             (
              .clk   (clk),
              .reset (reset),
              .wdata (int_wdata),
              .addr  (int_addr ),
              .wstrb (int_wstrb),
              .rdata (int_rdata),
              .valid (int_valid),
              .ready (int_ready),
              //
              // AXI INTERFACE
              //
              //address write
              .axi_awid   (axi_awid), 
              .axi_awaddr (axi_awaddr), 
              .axi_awlen  (axi_awlen), 
              .axi_awsize (axi_awsize), 
              .axi_awburst(axi_awburst), 
              .axi_awlock (axi_awlock), 
              .axi_awcache(axi_awcache), 
              .axi_awprot (axi_awprot),
              .axi_awqos  (axi_awqos), 
              .axi_awvalid(axi_awvalid), 
              .axi_awready(axi_awready), 
              //write
              .axi_wdata (axi_wdata), 
              .axi_wstrb (axi_wstrb), 
              .axi_wlast (axi_wlast), 
              .axi_wvalid(axi_wvalid), 
              .axi_wready(axi_wready), 
              //write response
              .axi_bid   (axi_bid), 
              .axi_bresp (axi_bresp), 
              .axi_bvalid(axi_bvalid), 
              .axi_bready(axi_bready), 
              //address read
              .axi_arid   (axi_arid), 
              .axi_araddr (axi_araddr), 
              .axi_arlen  (axi_arlen), 
              .axi_arsize (axi_arsize), 
              .axi_arburst(axi_arburst), 
              .axi_arlock (axi_arlock), 
              .axi_arcache(axi_arcache), 
              .axi_arprot (axi_arprot), 
              .axi_arqos  (axi_arqos), 
              .axi_arvalid(axi_arvalid), 
              .axi_arready(axi_arready), 
              //read 
              .axi_rid   (axi_rid), 
              .axi_rdata (axi_rdata), 
              .axi_rresp (axi_rresp), 
              .axi_rlast (axi_rlast), 
              .axi_rvalid(axi_rvalid),  
              .axi_rready(axi_rready)
              );
        end
      else
        begin
           
           iob_cache #(
                       .FE_ADDR_W    (L2_ADDR_W),
                       .FE_DATA_W    (L2_DATA_W),
                       .N_WAYS    (L2_N_WAYS),
                       .LINE_OFF_W(L2_LINE_OFF_W),
                       .WORD_OFF_W(L2_WORD_OFF_W),
                       .BE_ADDR_W(L2_MEM_ADDR_W),
                       .BE_DATA_W(L2_MEM_DATA_W),
                       .REP_POLICY(L2_REP_POLICY),
                       .WTBUF_DEPTH_W (L2_WTBUF_DEPTH_W),
                       .LA_INTERF     (0),
                       .CTRL_CNT      (0)
                       )
           L2 
             (
              .clk   (clk),
              .reset (reset),
              .wdata (int_wdata),
              .addr  (int_addr ),
              .wstrb (int_wstrb),
              .rdata (int_rdata),
              .valid (int_valid),
              .ready (int_ready),
              .select(1'b0),
              //
              // NATIVE MEMORY INTERFACE
              //
              .mem_addr (mem_addr),
              .mem_wdata(mem_wdata),
              .mem_wstrb(mem_wstrb),
              .mem_rdata(mem_rdata),
              .mem_valid(mem_valid),
              .mem_ready(mem_ready)
              );
           
        end // if (!AXI_INTERF)
   endgenerate
   
endmodule // L2-ID-2sp
