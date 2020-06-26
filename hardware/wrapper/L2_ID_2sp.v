`timescale 1ns/1ps
`include "iob-cache.vh"
///////////
// Wrapper:
/////////////////////////////////////////////////////////////
// L2 cache connected to an L1 Instruction and Data caches //
//  2 Master separated single-ports connected to 1 Slave   //                      
/////////////////////////////////////////////////////////////


module L2-ID_2sp
  #(
    //General parameters
    parameter DATA_W = 32
    parameter ADDR_W = 32,
    //Look-ahead Interface - Store Front-End input signals
    parameter LA_INTERF = 0,
    //Controller's options
    parameter CTRL_CNT_ID = 1, //Counters for both Data and Instruction Hits and Misses
    
    ///////////////////
    // L2 parameters //
    ///////////////////
    //Front-End L2 parameters will be equal from the L1 Back-End's
    parameter L2_ADDR_W   = ADDR_W,   //Address width - width that will used for the cache 
    parameter L2_DATA_W   = DATA_W,   //Data width - word size used for the cache
    parameter L2_N_WAYS   = 8,        //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter L2_LINE_OFF_W  = 4,     //Line-Offset Width - 2**NLINE_W total cache lines
    parameter L2_WORD_OFF_W = 4,      //Word-Offset Width - 2**OFFSET_W total DATA_W words per line - WARNING about MEM_OFFSET_W (can cause word_counter [-1:0] if the cache line is equal or less than the Data width in the back-end
    parameter L2_WTBUF_DEPTH_W = 4,   //Depth Width of Write-Through Buffer
    //Replacement policy (N_WAYS > 1)
    parameter L2_REP_POLICY = `LRU, //LRU - Least Recently Used ; BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    //Higher hierarchy memory (slave) interface parameters 
    parameter L2_MEM_NATIVE = 0,      //Cache's higher level memory interface: AXI(0-default), Native(1)
    parameter L2_MEM_ADDR_W = ADDR_W, //Address width of the higher hierarchy memory
    parameter L2_MEM_DATA_W = DATA_W, //Data width of the memory 
    //AXI specific parameters
    parameter L2_AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] L2_AXI_ID = 0, //AXI ID value
    /*---------------------------------------------------*/
    //Do NOT change this parameters - dependencies
    //parameter MEM_NBYTES = MEM_DATA_W/8, //Number of bytes
    
    /////////////////////////
    // L1-Instr parameters //
    /////////////////////////
    
    parameter L1_I_ADDR_W   = ADDR_W,   //Address width - width that will used for the cache 
    parameter L1_I_DATA_W   = DATA_W,   //Data width - word size used for the cache
    parameter L1_I_N_WAYS     = 1,      //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter L1_I_LINE_OFF_W = 4,      //Line-Offset Width - 2**NLINE_W total cache lines
    parameter L1_I_WORD_OFF_W = 3,      //Word-Offset Width - 2**OFFSET_W total DATA_W words per line - WARNING about MEM_OFFSET_W (can cause word_counter [-1:0]
    parameter L1_I_WTBUF_DEPTH_W = 4,   //Depth Width of Write-Through Buffer
    //Replacement policy (N_WAYS > 1)
    parameter L1_I_REP_POLICY = `LRU, //LRU - Least Recently Used ; BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    //Look-ahead Interface - Store Front-End input signals
    parameter L1_I_LA_INTERF = LA_INTERF, //default value
    //Controller counters
    parameter L1_I_CTRL_CNT = CTRL_CNT_ID,//default value
    /*---------------------------------------------------*/
    //Do NOT change this parameters - dependencies
    //parameter L1_I_N_BYTES  = L1_I_DATA_W/8,       //Number of Bytes per Word
    
    ////////////////////////
    // L1-Data parameters //
    ////////////////////////
    
    parameter L1_D_ADDR_W   = ADDR_W,   //Address width - width that will used for the cache 
    parameter L1_D_DATA_W   = DATA_W,   //Data width - word size used for the cache
    parameter L1_D_N_WAYS      = 1,     //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter L1_D_LINE_OFF_W  = 4,     //Line-Offset Width - 2**NLINE_W total cache lines
    parameter L1_D_WORD_OFF_W  = 3,     //Word-Offset Width - 2**OFFSET_W total DATA_W words per line - WARNING about MEM_OFFSET_W (can cause word_counter [-1:0]
    parameter L1_D_WTBUF_DEPTH_W = 4,   //Depth Width of Write-Through Buffer
    //Replacement policy (N_WAYS > 1)
    parameter L1_D_REP_POLICY = `LRU, //LRU - Least Recently Used ; BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    //Look-ahead Interface - Store Front-End input signals
    parameter L1_D_LA_INTERF = LA_INTERF, //default value
    //Controller counters
    parameter L1_D_CTRL_CNT = CTRL_CNT_ID//default value 
    /*---------------------------------------------------*/
    //Do NOT change this parameters - dependencies
    //parameter L1_D_N_BYTES  = L1_D_DATA_W/8       //Number of Bytes per Word
    )
   (
    // General ports
    input                                            clk,
    input                                            reset,
    // L1 - Instr ports
    input [L1_I_ADDR_W-1:$clog2(L1_I_DATA_W/8)]      i_addr, // cache_addr[ADDR_W] (MSB) selects cache (0) or controller (1)
    input                                            i_select,
    input [L1_I_DATA_W-1:0]                          i_wdata,
    input [L1_I_N_BYTES-1:0]                         i_wstrb,
    output [L1_I_DATA_W-1:0]                         i_rdata,
    input                                            i_valid,
    output                                           i_ready,
   
    // L1 - Data ports
    input [L1_D_ADDR_W-1:$clog2(L1_D_DATA_W)]        d_addr, // cache_addr[ADDR_W] (MSB) selects cache (0) or controller (1)
    input                                            d_select,
    input [L1_D_DATA_W-1:0]                          d_wdata,
    input [L1_D_N_BYTES-1:0]                         d_wstrb,
    output [L1_D_DATA_W-1:0]                         d_rdata,
    input                                            d_valid,
    output                                           d_ready,


    // L2  ports
    // AXI interface 
    // Address Write
    output [L2_AXI_ID_W-1:0]                         axi_awid, 
    output [L2_MEM_ADDR_W-1:0]                       axi_awaddr,
    output [7:0]                                     axi_awlen,
    output [2:0]                                     axi_awsize,
    output [1:0]                                     axi_awburst,
    output [0:0]                                     axi_awlock,
    output [3:0]                                     axi_awcache,
    output [2:0]                                     axi_awprot,
    output [3:0]                                     axi_awqos,
    output                                           axi_awvalid,
    input                                            axi_awready,
    //Write
    output [L2_MEM_DATA_W-1:0]                       axi_wdata,
    output [L2_MEM_NBYTES-1:0]                       axi_wstrb,
    output                                           axi_wlast,
    output                                           axi_wvalid, 
    input                                            axi_wready,
    input [L2_AXI_ID_W-1:0]                          axi_bid,
    input [1:0]                                      axi_bresp,
    input                                            axi_bvalid,
    output                                           axi_bready,
    //Address Read
    output [L2_AXI_ID_W-1:0]                         axi_arid,
    output [L2_MEM_ADDR_W-1:0]                       axi_araddr, 
    output [7:0]                                     axi_arlen,
    output [2:0]                                     axi_arsize,
    output [1:0]                                     axi_arburst,
    output [0:0]                                     axi_arlock,
    output [3:0]                                     axi_arcache,
    output [2:0]                                     axi_arprot,
    output [3:0]                                     axi_arqos,
    output                                           axi_arvalid, 
    input                                            axi_arready,
    //Read
    input [L2_AXI_ID_W-1:0]                          axi_rid,
    input [L2_MEM_DATA_W-1:0]                        axi_rdata,
    input [1:0]                                      axi_rresp,
    input                                            axi_rlast, 
    input                                            axi_rvalid, 
    output                                           axi_rready,
    //Native interface
    output [L2_MEM_ADDR_W-1:$clog2(L2_MEM_DATA_W/8)] mem_addr,
    output                                           mem_valid,
    input                                            mem_ready,
    output [L2_MEM_DATA_W-1:0]                       mem_wdata,
    output [L2_MEM_NBYTES-1:0]                       mem_wstrb,
    input [L2_MEM_DATA_W-1:0]                        mem_rdata
    );
   
   //L1-I
   wire [`L1_I_MEM_ADDR_W-1:$clog2(`L1_I_MEM_N_BYTES)] i_mem_addr;
   wire [`L1_I_MEM_DATA_W-1:0]                         i_mem_wdata, i_mem_rdata;
   wire [`L1_I_MEM_N_BYTES-1:0]                        i_mem_wstrb;
   wire                                                i_mem_valid, i_mem_ready;
   //L1-D
   wire [`L1_D_MEM_ADDR_W-1:$clog2(`L1_D_MEM_N_BYTES)] d_mem_addr;
   wire [`L1_D_MEM_DATA_W-1:0]                         d_mem_wdata, d_mem_rdata;
   wire [`L1_D_MEM_N_BYTES-1:0]                        d_mem_wstrb;
   wire                                                d_mem_valid, d_mem_ready;
   //L2
   wire [`L2_MEM_ADDR_W-1:$clog2(`L2_MEM_N_BYTES)]     int_addr;
   wire [`L2_MEM_DATA_W-1:0]                           int_wdata, int_rdata;
   wire [`L2_MEM_N_BYTES-1:0]                          int_wstrb;
   wire                                                int_valid, int_ready;


   iob_cache #(
               .ADDR_W     (`L1_I_ADDR_W),
               .DATA_W     (`L1_I_DATA_W),
               .N_WAYS     (`L1_I_N_WAYS),
               .LINE_OFF_W (`L1_I_LINE_OFF_W),
               .WORD_OFF_W (`L1_I_WORD_OFF_W),
               .MEM_ADDR_W (`L2_ADDR_W),
               .MEM_DATA_W (`L2_DATA_W),
               .REP_POLICY (`L1_I_REP_POLICY),
               .WTBUF_DEPTH_W (`L1_I_WTBUF_DEPTH_W)
               .LA_INTERF     (`L1_I_LA_INTERF),
               .MEM_NATIVE    (1),
               .CTRL_CNT_ID   (0),
               .CTRL_CNT      (`L1_I_CTRL_CNT)
               )
   L1_I
     (
      .clk   (clk),
      .reset (reset),
      .wdata (i_wdata),
      .addr  (i_addr ),
      .wstrb (i_wstrb),
      .rdata (i_rdata),
      .valid (i_valid),
      .ready (i_ready),
      .instr (1'b1),
      .select(i_select),
      //
      // NATIVE MEMORY INTERFACE
      //
      .mem_addr (i_mem_addr),
      .mem_wdata(i_mem_wdata),
      .mem_wstrb(i_mem_wstrb),
      .mem_rdata(i_mem_rdata),
      .mem_valid(i_mem_valid),
      .mem_ready(i_mem_ready)
      );



   
   iob_cache #(
               .ADDR_W     (`L1_D_ADDR_W),
               .DATA_W     (`L1_D_DATA_W),
               .N_WAYS     (`L1_D_N_WAYS),
               .LINE_OFF_W (`L1_D_LINE_OFF_W),
               .WORD_OFF_W (`L1_D_WORD_OFF_W),
               .MEM_ADDR_W (`L2_ADDR_W),
               .MEM_DATA_W (`L2_DATA_W),
               .REP_POLICY (`L1_D_REP_POLICY),
               .WTBUF_DEPTH_W (`L1_D_WTBUF_DEPTH_W)
               .LA_INTERF     (`L1_D_LA_INTERF),
               .MEM_NATIVE    (1),
               .CTRL_CNT_ID   (0),
               .CTRL_CNT      (`L1_D_CTRL_CNT)
               )
   L1_D
     (
      .clk   (clk),
      .reset (reset),
      .wdata (d_wdata),
      .addr  (d_addr ),
      .wstrb (d_wstrb),
      .rdata (d_rdata),
      .valid (d_valid),
      .ready (d_ready),
      .instr (1'b0),
      .select(d_select),
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

   
   mm2ss_interconnect #(
                        .N_MASTERS(2),
                        .ADDR_W(`L2_ADDR_W),
                        .DATA_W(`L2_DATA_W)
                        )
   cache_inter
     (
      .cat_bus_fe_in  ({{i_mem_valid, i_mem_addr, i_mem_wdata, i_mem_wstrb},{d_mem_valid, d_mem_addr, d_mem_wdata, d_mem_wstrb}}),
      .cat_bus_fe_out ({{i_mem_ready, i_mem_rdata},{d_mem_ready, d_mem_rdata}}),
      .cat_bus_be_in  ({int_ready, int_rdata}),
      .cat_but_be_out ({int_valid, int_addr, int_wdata, int_wstrb})
      );
   


   
   

   iob_cache #(
               .ADDR_W    (`L2_ADDR_W),
               .DATA_W    (`L2_DATA_W),
               .N_WAYS    (`L2_N_WAYS),
               .LINE_OFF_W(`L2_LINE_OFF_W),
               .WORD_OFF_W(`L2_WORD_OFF_W),
               .MEM_ADDR_W(`L2_MEM_ADDR_W),
               .MEM_DATA_W(`L2_MEM_DATA_W),
               .MEM_NATIVE(`L2_MEM_NATIVE),
               .REP_POLICY(`L2_REP_POLICY),
               .WTBUF_DEPTH_W (`L2_WTBUF_DEPTH_W)
               .LA_INTERF     (0),
               .CTRL_CNT_ID   (0),
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
      .instr (1'b0),
      .select(1'b0),
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
      .axi_rready(axi_rready),
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
   
endmodule // L2-ID-2sp





module mm2ss_interconnect
  #(
    parameter N_MASTERS = 2,
    parameter ADDR_W = 32,
    parameter DATA_W = 32
    )
   (
    //  input                             clk,
    //  input                             rst,

    //front-end 
    input [N_MASTERS*(1+ADDR_W+DATA_W+DATA_W/8)-1:0] cat_bus_fe_in, //n*(valid+addr+wdata+wstrb)
    output [N_MASTERS*(1+DATA_W)-1:0]                cat_bus_fe_out, //n*(ready+rdata)


    //back-end 
    input [DATA_W:0]                                 cat_bus_be_in, //ready+rdata
    output [ADDR_W+DATA_W+DATA_W/8:0]                cat_bus_be_out //valid+addr+wdata+wstrb
    );

   //parameter N_MASTERS_W = $clog2(N_MASTERS);

   parameter BUS_IN_LEN = 1+ADDR_W+DATA_W+DATA_W/8;
   parameter BUS_OUT_LEN = 1+DATA_W;
   
   //extract valid bit mask;
   wire [N_MASTERS-1:0]                              m_valid;
   genvar                                            i;
   generate for (i=0; i<N_MASTERS; i=i+1) begin: vb_loop
      assign m_valid[i] = cat_bus_in[(i+1)*BUS_IN_LEN-1];
   end
   endgenerate

   //PRIORITY ENCODE CAT BUS
   wire [BUS_IN_LEN-1:0]  pe_out;
   priority_enc 
     #(
       .N(N_MASTERS), .M(BUS_IN_LEN)
       ) 
   pe (
       .valid(m_valid),
       .word_in({cat_bus_fe_in}),
       .word_out(cat_bus_be_out)
       );


   //GET RESPONSE CAT WORD 

   //compute leading 1 mask of valid bit mask
   wire [N_MASTERS-1:0]   l1me;    
   leading1_mask_enc #(.N(N_MASTERS)) l1mencoder (.valid(m_valid), .l1me(l1me));

   //expand back-end input bus using leading 1 mask
   expand_word
     #(
       .N(N_MASTERS), .M(BUS_OUT_LEN)
       ) 
   word_epander 
     (
      .valid(l1me),
      .word_in({cat_bus_be_in}),
      .word_out(cat_bus_fe_out)
      );

   /* 
    always @(posedge clk, posedge rst)
    if(rst)
    m_valid_reg <= {N_MASTERS{1'b0}};
    else
    m_valid_reg <= m_valid;
    */ 

   
endmodule // mm2ss_interconnect



//
// inputs N concatenated M-bit words and respective valid bits
// outputs left most valid word
//


module priority_enc
  #(
    parameter N = 4, //NUMBER OF WORDS
    parameter M = 4 //WORD WIDTH
    )
   (
    input [N-1:0]   valid,
    input [N*M-1:0] word_in,
    output [M-1:0]  word_out
    );


   wire [N-1:0]     l1m; //bit leading one mask
   wire [N*M-1:0]   wmask;//word level mask
   
   //M-bit OR-sumation words
   wire [M-1:0]     orsum [N:0];

   leading1_mask_enc #(.N(N)) l1mask_enc (.valid(valid), .l1me(l1m));

   expand_mask #(.N(N), .M(M)) mask_expand (.mask_in(l1m), .mask_out(wmask));
   
   genvar           i;

   //apply mask to N-word input and accumulate
   assign orsum[0] = {M{1'b0}};
   generate
      for (i=1; i<=N; i=i+1) begin : s_loop
         assign orsum[i] = orsum[i-1] + (wmask[i*M-1 -: M] & word_in[i*M-1 -: M]);
      end
   endgenerate

   assign word_out = orsum[N];
   
endmodule // priority_enc





module expand_word
  #(
    parameter N = 4, //number of words
    parameter M = 4  //word width
    )
   (
    input [N-1:0]    valid,
    input [M-1:0]    word_in,
    output [N*M-1:0] cat_bus_out
    );

   //create expanded valid mask
   wire [N*M-1:0]    expanded_valid;          
   expand_mask  #(.N(N), .M(M)) expander (.mask_in(valid), .mask_out(expanded_valid) );
   

   //create word of replicated input words
   genvar            i;
   wire [N*M-1:0]    replicated;
   
   generate 
      for (i=0; i<N; i=i+1) begin : m_loop
         assign replicated[(i+1)*M-1 -: M] = word_in;
      end
   endgenerate

   //apply expanded valid mask to replicated
   assign cat_bus_out = expanded_valid & replicated;
   
endmodule // expand_word




module leading1_mask_enc
  #(
    parameter N = 4 //WORD WIDTH
    )
   (
    input [N-1:0]  valid,
    output [N-1:0] l1me
    );

   wire [N:0]      l1; //leading ones representation

   wire [N-1:0]    l1me; //leading 1 mask
   
   genvar          i;
   
   //generate leading ones encoding (l1e):
   //replaces leading 0s with 1s
   //replaces rest of word with zero
   
   assign l1[N] = 1'b1;  
   generate 
      for (i=N-1; i>=0; i=i-1) begin : l1_loop
         assign l1[i] = l1[i+1] & ~valid[i];
      end
   endgenerate  

   //generate leading ones mask (l1m) from l1e:
   //replace leading ones with zeros
   //replace most signicant 0 with 1

   generate 
      for (i=N; i>0; i=i-1) begin : l1me_loop
         assign l1me[i-1] = l1[i] & ~l1[i-1];
      end
   endgenerate
   
endmodule // leading1_mask_enc



module expand_mask
  #(
    parameter N = 4, //number of words
    parameter M = 4  //word width
    )
   (
    input [N-1:0]    mask_in,
    output [N*M-1:0] mask_out
    );

   genvar            i;
   //generate masks
   generate 
      for (i=0; i<N; i=i+1) begin : m_loop
         assign mask_out[(i+1)*M-1 -: M] = {M{mask_in[i]}};
      end
   endgenerate
   
endmodule
