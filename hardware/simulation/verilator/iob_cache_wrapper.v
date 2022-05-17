`timescale 1ns / 1ps

module iob_cache_wrapper
     #(       
       parameter FE_ADDR_W = 32,              
       parameter FE_DATA_W = 32,                         
       parameter BE_ADDR_W = 24, 
       parameter BE_DATA_W = 32,
       parameter AXI_ID_W = 1
      )
      (   
       input 				  clk,
       input 				  reset,
	  
       input 				         req, 
       input  [FE_ADDR_W-1:$clog2(FE_DATA_W/8)]  addr,
       input  [FE_DATA_W-1:0] 		         wdata,
       input  [FE_DATA_W/8-1:0] 		 wstrb,
       output [FE_DATA_W-1:0] 		         rdata,
       output 				         ack      
      );	

       wire                                axi_arvalid; 
       wire [BE_ADDR_W-1:0]                axi_araddr;
       wire [7:0]                          axi_arlen;
       wire [2:0]                          axi_arsize;
       wire [1:0]                          axi_arburst;
       wire                                axi_arlock;
       wire [3:0]                          axi_arcache;
       wire [2:0]                          axi_arprot;   
       wire [AXI_ID_W-1:0]                 axi_arid;
       wire                                axi_arready;
       wire                                axi_rvalid; 
       wire [BE_DATA_W-1:0]                axi_rdata;
       wire [1:0]                          axi_rresp;
       wire                                axi_rlast; 
       wire                                axi_rready;
       wire                                axi_awvalid;
       wire [BE_ADDR_W-1:0]                axi_awaddr;
       wire [7:0]                          axi_awlen;
       wire [2:0]                          axi_awsize;
       wire [1:0]                          axi_awburst;
       wire                                axi_awlock;
       wire [3:0]                          axi_awcache;
       wire [2:0]                          axi_awprot;
       wire [AXI_ID_W-1:0]                 axi_awid;
       wire                                axi_awready;
       wire                                axi_wvalid;
       wire [BE_DATA_W-1:0]                axi_wdata;
       wire [BE_DATA_W/8-1:0]              axi_wstrb;
       wire                                axi_wlast;
       wire                                axi_wready;
       wire                                axi_bvalid;
       wire [1:0]                          axi_bresp;
       wire                                axi_bready;

       wire [AXI_ID_W-1:0]                 axi_bid; 
       wire [AXI_ID_W-1:0]                 axi_rid;
       
       wire [3:0]                          axi_arqos;    
       wire [3:0]                          axi_awqos;    

   iob_cache_axi 
     #(
       .FE_ADDR_W(FE_ADDR_W),       
       .FE_DATA_W(FE_DATA_W),
       .BE_ADDR_W(BE_ADDR_W),
       .BE_DATA_W(BE_DATA_W)
      ) 
   cache_axi    
      (
       .clk(clk),
       .reset(reset),
       .req(req),
       .addr(addr),
       .wdata(wdata),
       .wstrb(wstrb),
       .rdata(rdata),
       .ack(ack),   
       .invalidate_in(1'b0),
       .invalidate_out(),
       .wtb_empty_in(1'b1),
       .wtb_empty_out(),
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
       .axi_rvalid(axi_rvalid), 
       .axi_rdata(axi_rdata),
       .axi_rresp(axi_rresp),
       .axi_rlast(axi_rlast), 
       .axi_rready(axi_rready),    
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
       .axi_wvalid(axi_wvalid), 
       .axi_wdata(axi_wdata),
       .axi_wstrb(axi_wstrb),
       .axi_wlast(axi_wlast),
       .axi_wready(axi_wready),
       .axi_bvalid(axi_bvalid),
       .axi_bresp(axi_bresp),
       .axi_bready(axi_bready)
       );


   axi_ram
      #(
       .DATA_WIDTH(BE_DATA_W),
       .ADDR_WIDTH(BE_ADDR_W),
       .ID_WIDTH(AXI_ID_W)
      )
   ddr_axi
      (
       .clk(clk),
       .rst(reset),
       .s_axi_awid(axi_awid),
       .s_axi_awaddr(axi_awaddr),
       .s_axi_awlen(axi_awlen),
       .s_axi_awsize(axi_awsize),
       .s_axi_awburst(axi_awburst),
       .s_axi_awlock(axi_awlock),
       .s_axi_awcache(axi_awcache),
       .s_axi_awprot(axi_awprot),
       .s_axi_awvalid(axi_awvalid),
       .s_axi_awready(axi_awready),
       .s_axi_wdata(axi_wdata),
       .s_axi_wstrb(axi_wstrb),
       .s_axi_wlast(axi_wlast),
       .s_axi_wvalid(axi_wvalid),
       .s_axi_wready(axi_wready),
       .s_axi_bid(axi_bid),	
       .s_axi_bresp(axi_bresp),
       .s_axi_bvalid(axi_bvalid),
       .s_axi_bready(axi_bready),
       .s_axi_arid(axi_arid),
       .s_axi_araddr(axi_araddr),
       .s_axi_arlen(axi_arlen),
       .s_axi_arsize(axi_arsize),
       .s_axi_arburst(axi_arburst),
       .s_axi_arlock(axi_arlock),
       .s_axi_arcache(axi_arcache),
       .s_axi_arprot(axi_arprot),
       .s_axi_arvalid(axi_arvalid),
       .s_axi_arready(axi_arready),
       .s_axi_rid(axi_rid),        
       .s_axi_rdata(axi_rdata),
       .s_axi_rresp(axi_rresp),
       .s_axi_rlast(axi_rlast),
       .s_axi_rvalid(axi_rvalid),
       .s_axi_rready(axi_rready)
      );
      
endmodule   //iob_cache_wrapper


