`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "iob_cache.vh"

module iob_cache_wrapper
      (
       input                              clk,
       input                              reset,
       
       input                              req, 
       input  [`ADDR_W:$clog2(`DATA_W/8)] addr,
       input  [`DATA_W-1:0]               wdata,
       input  [`DATA_W/8-1:0]             wstrb,
       output [`DATA_W-1:0]               rdata,
       output                             ack      
       );	

`ifdef AXI
   localparam AXI_ADDR_W = `BE_ADDR_W;
   localparam AXI_DATA_W = `BE_DATA_W;
 `include "iob_cache_axi_wire.vh"
`else
   //Native connections
   wire [`BE_ADDR_W-1:0]           be_addr;
   wire [`BE_DATA_W-1:0]           be_wdata, be_rdata;
   wire [`BE_DATA_W/8-1:0]         be_wstrb;
   wire                            be_req;
   reg                             be_ack;
   
`endif  

 
`ifdef AXI   
   iob_cache_axi
`else
   iob_cache_iob
`endif     
     #(
       .ADDR_W(`ADDR_W),
       .DATA_W(`DATA_W),
       .BE_ADDR_W(`BE_ADDR_W),
       .BE_DATA_W(`BE_DATA_W),
       .NWAYS_W(`NWAYS_W),
       .NLINES_W(`NLINES_W),
       .WORD_OFFSET_W(`WORD_OFFSET_W),
       .WTBUF_DEPTH_W(`WTBUF_DEPTH_W),
       .WRITE_POL(`WRITE_POL),
       .REP_POLICY(`REP_POLICY),
       .CTRL_CACHE(1)
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
       .ID_WIDTH(`AXI_ID_W),
       .DATA_WIDTH (`BE_DATA_W),
       .ADDR_WIDTH (`BE_ADDR_W)
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
       .DATA_W(`BE_DATA_W),
       .ADDR_W(`BE_ADDR_W)
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

endmodule   //iob_cache_wrapper


