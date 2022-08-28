`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "iob_cache.vh"
`include "iob_cache_conf.vh"
`include "iob_cache_tb_conf.vh"

module iob_cache_wrapper
      (
       input                               clk,
       input                               reset,
       
       input                               req,
       input [`IOB_CACHE_ADDR_W-1:$clog2(`IOB_CACHE_DATA_W/8)] addr,
       input [`IOB_CACHE_DATA_W-1:0]                 wdata,
       input [`IOB_CACHE_DATA_W/8-1:0]               wstrb,
       output [`IOB_CACHE_DATA_W-1:0]                rdata,
       output                              ack
       );	

`ifdef AXI
   localparam AXI_ADDR_W = `IOB_CACHE_BE_ADDR_W;
   localparam AXI_DATA_W = `IOB_CACHE_BE_DATA_W;
   localparam AXI_ID_W = `IOB_CACHE_AXI_ID_W;
   localparam AXI_LEN_W = `IOB_CACHE_AXI_LEN_W;
 `include "iob_cache_axi_wire.vh"
`else
   //Native connections
   wire [`IOB_CACHE_BE_ADDR_W-1:0]           be_addr;
   wire [`IOB_CACHE_BE_DATA_W-1:0]           be_wdata, be_rdata;
   wire [`IOB_CACHE_BE_DATA_W/8-1:0]         be_wstrb;
   wire                            be_req;
   reg                             be_ack;
   
`endif  

 
`ifdef AXI   
   iob_cache_axi
`else
   iob_cache_iob
`endif     
     #(
       .ADDR_W(`IOB_CACHE_ADDR_W),
       .DATA_W(`IOB_CACHE_DATA_W),
       .BE_ADDR_W(`IOB_CACHE_BE_ADDR_W),
       .BE_DATA_W(`IOB_CACHE_BE_DATA_W),
       .NWAYS_W(`IOB_CACHE_NWAYS_W),
       .NLINES_W(`IOB_CACHE_NLINES_W),
       .WORD_OFFSET_W(`IOB_CACHE_WORD_OFFSET_W),
       .WTBUF_DEPTH_W(`IOB_CACHE_WTBUF_DEPTH_W),
       .WRITE_POL(`IOB_CACHE_WRITE_POL),
       .REP_POLICY(`IOB_CACHE_REP_POLICY),
       .USE_CTRL(`IOB_CACHE_USE_CTRL)
       )
`ifdef AXI   
   cache_axi
`else
   cache_iob
`endif     
      (
      //front-end
      .wdata (wdata),
      .addr  (addr),
      .wstrb (wstrb),
      .rdata (rdata),
      .req (req),
      .ack (ack),

      //invalidate / wtb empty
      .invalidate_in(1'b0),
      .invalidate_out(),
      .wtb_empty_in(1'b1),
      .wtb_empty_out(),

      //back-end
`ifdef AXI
  `include "iob_cache_axi_portmap.vh"
`else
      .be_addr(be_addr),
      .be_wdata(be_wdata),
      .be_wstrb(be_wstrb),
      .be_rdata(be_rdata),
      .be_req(be_req),
      .be_ack(be_ack),
`endif
      .clk (clk),
      .rst (reset)
      );
   
   
`ifdef AXI  
   axi_ram 
     #(
       .ID_WIDTH(`IOB_CACHE_AXI_ID_W),
       .LEN_WIDTH(`IOB_CACHE_AXI_LEN_W),
       .DATA_WIDTH (`IOB_CACHE_BE_DATA_W),
       .ADDR_WIDTH (`IOB_CACHE_BE_ADDR_W)
       )
   axi_ram
     (
      //address write
      .clk            (clk),
      .rst            (reset),
      .s_axi_awid     (axi_awid),
      .s_axi_awaddr   (axi_awaddr),
      .s_axi_awlen    (axi_awlen),
      .s_axi_awsize   (axi_awsize),
      .s_axi_awburst  (axi_awburst),
      .s_axi_awlock   (axi_awlock),
      .s_axi_awprot   (axi_awprot),
      .s_axi_awcache  (axi_awcache),
      .s_axi_awqos    (axi_awqos),
      .s_axi_awvalid  (axi_awvalid),
      .s_axi_awready  (axi_awready),
      
      //write  
      .s_axi_wvalid   (axi_wvalid),
      .s_axi_wready   (axi_wready),
      .s_axi_wdata    (axi_wdata),
      .s_axi_wstrb    (axi_wstrb),
      .s_axi_wlast    (axi_wlast),
      
      //write response
      .s_axi_bready   (axi_bready),
      .s_axi_bid      (axi_bid),
      .s_axi_bresp    (axi_bresp),
      .s_axi_bvalid   (axi_bvalid),
      
      //address read
      .s_axi_arid     (axi_arid),
      .s_axi_araddr   (axi_araddr),
      .s_axi_arlen    (axi_arlen), 
      .s_axi_arsize   (axi_arsize),    
      .s_axi_arburst  (axi_arburst),
      .s_axi_arlock   (axi_arlock),
      .s_axi_arcache  (axi_arcache),
      .s_axi_arprot   (axi_arprot),
      .s_axi_arqos    (axi_arqos),
      .s_axi_arvalid  (axi_arvalid),
      .s_axi_arready  (axi_arready),
      
      //read   
      .s_axi_rready   (axi_rready),
      .s_axi_rid      (axi_rid),
      .s_axi_rdata    (axi_rdata),
      .s_axi_rresp    (axi_rresp),
      .s_axi_rlast    (axi_rlast),
      .s_axi_rvalid   (axi_rvalid)
      ); 
   
`else

   iob_ram_sp_be 
     #(
       .DATA_W(`IOB_CACHE_BE_DATA_W),
       .ADDR_W(`IOB_CACHE_BE_ADDR_W)
       )
   native_ram
     (
      .clk(clk),
      .en  (be_req),
      .we  (be_wstrb),
      .addr(be_addr),
      .dout(be_rdata),
      .din (be_wdata)
      );
   
   always @(posedge clk)
     be_ack <= be_req;
   
`endif

   initial begin
`ifdef AXI
   $display("\nTesting Cache with AXI4 Backend");
`else
   $display("\nTesting Cache with IOB Backend");
`endif
   end
  
endmodule   //iob_cache_wrapper


