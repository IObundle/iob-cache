`timescale 1ns/10ps

`include "iob-cache_tb.vh"

module iob_cache_tb;

   reg clk = 1;
   always #1 clk = ~clk;
   reg reset = 1;

   reg [`ADDR_W  :$clog2(`N_BYTES)] addr =0;
   reg [`DATA_W-1:0]                wdata=0;
   reg [`N_BYTES-1:0]               wstrb=0;
   reg                              valid=0;
   wire [`DATA_W-1:0]                rdata;
   wire                              ready;
   

   integer                          i;
   
   initial 
     begin
        
`ifdef VCD
	$dumpfile("iob_cache.vcd");
	$dumpvars();
`endif  
        repeat (5) @(posedge clk);
        reset <= 0;
        #10
        $display("Writing entire memory\n");
        for (i = 0; i < 2**(`ADDR_W-$clog2(`N_BYTES)); i = i + 1)
        //for (i = 0; i < 10; i = i + 1)
          begin
             addr <= i;
             wdata <= i;
             wstrb <= {`N_BYTES{1'b1}};
             valid <= 1;
             #2;
             valid <=0;
             #10;
          end
        
        $display("Reading entire memory\n");
        for (i = 0; i < 2**(`ADDR_W-$clog2(`N_BYTES)); i = i + 1)
          //for (i = 0; i < 10; i = i + 1)
          begin
             addr <= i;
             wdata <= 0;
             wstrb <= {`N_BYTES{1'b0}};
             valid <= 1;
             #20;
             if(rdata != i)
               $display("Error in: %h\n", i);
             valid <= 0;
             #2;             
          end // for (i = 0; i < 2**`ADDR_W; i = i + 1)
        $display("Finished reading\n");
        $display("Test end\n");
        $finish;
     end
   

   //AXI connections
   wire 			   axi_awvalid;
   wire 			   axi_awready;
   wire [`MEM_ADDR_W-1:0]          axi_awaddr;
   wire [ 2:0]                     axi_awprot;
   wire 			   axi_wvalid;
   wire 			   axi_wready;
   wire [`MEM_DATA_W-1:0]          axi_wdata;
   wire [`MEM_N_BYTES-1:0]         axi_wstrb;
   wire 			   axi_bvalid;
   wire 			   axi_bready;
   wire 			   axi_arvalid;
   wire 			   axi_arready;
   wire [`MEM_ADDR_W-1:0]          axi_araddr;
   wire [ 2:0]                     axi_arprot;
   wire 			   axi_rvalid;
   wire 			   axi_rready;
   wire [`MEM_DATA_W-1:0]          axi_rdata;
   wire 			   axi_rlast;
   wire [1:0]                      axi_bresp;
   wire [7:0]                      axi_arlen;
   wire [2:0]                      axi_arsize;
   wire [1:0]                      axi_arburst;
   wire [7:0]                      axi_awlen;
   wire [2:0]                      axi_awsize;
   wire [1:0]                      axi_awburst;
   //Native connections
   wire [`MEM_ADDR_W-1:$clog2(`MEM_N_BYTES)] mem_addr;
   wire [`MEM_DATA_W-1:0]                    mem_wdata, mem_rdata;
   wire [`MEM_N_BYTES-1:0]                   mem_wstrb;
   wire                                      mem_valid, mem_ready;
   
   

   iob_cache #(
               .ADDR_W(`ADDR_W),
               .DATA_W(`DATA_W),
               .N_WAYS(`N_WAYS),
               .LINE_OFF_W(`LINE_OFF_W),
               .WORD_OFF_W(`WORD_OFF_W),
               .MEM_ADDR_W(`MEM_ADDR_W),
               .MEM_DATA_W(`MEM_DATA_W),
               .MEM_NATIVE(`MEM_NATIVE),
               .REP_POLICY(`REP_POLICY),
               .LA_INTERF(`LA)
               )
   cache (
	  .clk (clk),
	  .reset (reset),
	  .wdata (wdata),
	  .addr  ({1'b0,addr}),
	  .wstrb (wstrb),
	  .rdata (rdata),
	  .valid (valid),
	  .ready (ready),
	  .instr (instr),
          //
	  // AXI INTERFACE
          //
          //address write
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
          //write
          .axi_wdata(axi_wdata), 
          .axi_wstrb(axi_wstrb), 
          .axi_wlast(axi_wlast), 
          .axi_wvalid(axi_wvalid), 
          .axi_wready(axi_wready), 
          //write response
          .axi_bid(axi_bid), 
          .axi_bresp(axi_bresp), 
          .axi_bvalid(axi_bvalid), 
          .axi_bready(axi_bready), 
          //address read
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
          //read 
          .axi_rid(axi_rid), 
          .axi_rdata(axi_rdata), 
          .axi_rresp(axi_rresp), 
          .axi_rlast(axi_rlast), 
          .axi_rvalid(axi_rvalid),  
          .axi_rready(axi_rready),
          //
          // NATIVE MEMORY INTERFACE
          //
          .mem_addr(mem_addr),
          .mem_wdata(mem_wdata),
          .mem_wstrb(mem_wstrb),
          .mem_rdata(mem_rdata),
          .mem_valid(mem_valid),
          .mem_ready(mem_ready)
	  );
   

   axi_ram 
     #(
       .DATA_WIDTH (`MEM_DATA_W),
       .ADDR_WIDTH (`MEM_ADDR_W)
       )
   axi_ram(
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


   iob_sp_mem_be #(
		   .COL_WIDTH(8),
		   .NUM_COL(`MEM_DATA_W/8),
                   .ADDR_WIDTH(`MEM_ADDR_W)
                   )
   iob_gen_memory
     (
      .din(mem_wdata),
      .addr(mem_addr),
      .we(mem_wstrb), 
      .en(mem_valid),
      .clk(clk), 
      .dout(mem_rdata)
      );



   reg                                       aux_mem_ready;
   assign mem_ready = aux_mem_ready;
   
   always @(posedge clk) 
     begin
        aux_mem_ready <= mem_valid; 
     end  


endmodule // iob_cache_tb


