`timescale 1ns/10ps

`include "iob-cache_tb.vh"

module iob_cache_tb;

   reg clk = 1;
   always #1 clk = ~clk;
   reg reset = 1;
   
   reg [`ADDR_W-1  :$clog2(`DATA_W/8)] addr =0;
   reg [`DATA_W-1:0]                   wdata=0;
   reg [`DATA_W/8-1:0]                 wstrb=0;
   reg                                 valid=0;
   wire [`DATA_W-1:0]                  rdata;
   wire                                ready;
   reg                                 instr =0;
   wire                                select = 0;//cache is always selected
   wire                                i_select =0, d_select =0;
   reg [31:0]                          test = 0;
   

   integer                             i,j;
   
   initial 
     begin
        
`ifdef VCD
	$dumpfile("iob_cache.vcd");
	$dumpvars();
`endif  
        repeat (5) @(posedge clk);
        reset <= 0;
        #10;
        $display("\nInitializing Cache testing - printing errors only\n");
        $display("Test 1 - Writing entire memory (Data width words)\n");
        test <= 1;
        for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
          begin
             addr <= i;
             wdata <= i+1;
             wstrb <= {`DATA_W/8{1'b1}};
             valid <= 1;
             #2;
`ifdef LA
             addr <= 0;
             wdata <= 0;
             wstrb <= 0;
             valid <= 0;
`endif
             while (ready == 1'b0) #2;
             valid <= 0;
             #2;
          end // for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
        addr  <= 0;
        wdata <= 0;
        wstrb <= 0;
        #2;
        $display("Test 2 - Reading entire memory (Data width words)\n");
        test <= 2;
        #2
          for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
            begin 
               addr <= i;
               valid <= 1;
               #2;
`ifdef LA
               addr <= 0;
               valid <= 0;
`endif   
               while (ready == 1'b0) #2;
               if(rdata != (i+1))
                 $display("Error in: %h\n", i);
               valid <= 0;
               #2;
            end
        
        $display("Test 3 - Byte addressing (Writting memory using Bytes)\n");
        test <= 3;
        #2;
        for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
          begin
             for( j = 0; j < `DATA_W/8; j = j + 1)
               begin
                  addr <= i;
                  #2;
                  wdata <= {`DATA_W/8{i[3:0]}};
                  wstrb <= (1'b1) << j;
                  valid <= 1;
                  #2;
`ifdef LA
                  addr <= 0;
                  wdata <= 0;
                  wstrb <= 0;
                  valid <= 0;
`endif
                  while (ready == 1'b0) #2;
                  valid <= 0;
                  #2;
               end // for ( j = 0; j < `DATA_W/8; j = j + 1)
          end // for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
        wdata <= 0;
        wstrb <= 0;
        #2;
        $display("Test 4 - Reading Byte Addressing using Data Width Words - only for 32-bit (BE_DATA_W = 32)\n");
        test <= 4;
        #2;
        for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
          begin 
             addr <= i;
             valid <= 1;
             #2
`ifdef LA
               addr <= 0;
             valid <= 0;
`endif   
             while (ready == 1'b0) #2;
             if(rdata != {`DATA_W/8{i[3:0]}})
               $display("Error in: %h; wrote instead: %h\n", addr, rdata);
             valid <= 0;
             #2;
          end // for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)


/*
        $display("Test 5 - Forcing a cache-line load, followed by a write and a read to the same position");
        test <= 5;
        #8;
        addr <=0;
        wstrb <= 0;
        wdata <= 0;
        valid <= 1;
        #2;
        
        while(ready == 1'b0) #2;
        valid <= 0;
        #8;
        valid <= 1;
        
        wdata <= {`DATA_W{1'b1}};
        wstrb <= {`DATA_W/8{1'b1}};
        while(ready == 1'b0)#2;
        wdata <= 0;
        wstrb <= 0;
        while (ready == 1'b0) #2;
        if(rdata != {`DATA_W{1'b1}})
          $display("Data was accessed too early, still read: %h, instead of all HIGH",  rdata);
        #8;
        
        valid <= 0;
        #2;
*/        
        $display("Cache testing completed\n");
        $finish;
     end
   
`ifdef AXI
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
`else
   //Native connections
   wire [`MEM_ADDR_W-1:0]          mem_addr;
   wire [`MEM_DATA_W-1:0]          mem_wdata, mem_rdata;
   wire [`MEM_N_BYTES-1:0]         mem_wstrb;
   wire                            mem_valid;
   reg                             mem_ready;
   
`endif  
   

   
`ifdef L2
   
   L2_ID_1sp #(
               .FE_ADDR_W(`ADDR_W),
               .FE_DATA_W(`DATA_W),
               .BE_ADDR_W(`MEM_ADDR_W),
               .BE_DATA_W(`MEM_DATA_W),
 `ifdef AXI
               .AXI_INTERF(1),
 `else
               .AXI_INTERF(0),
 `endif
               .REP_POLICY(`REP_POLICY),
 `ifdef LA
               .LA_INTERF(1),
 `else
               .LA_INTERF(0),
 `endif
               .L1_LINE_OFF_W(`LINE_OFF_W),
               .L1_WORD_OFF_W(`WORD_OFF_W),
               .L2_LINE_OFF_W(`LINE_OFF_W),
               .L2_WORD_OFF_W(`WORD_OFF_W),
               .L2_N_WAYS    (`N_WAYS),
               .L1_WTBUF_DEPTH_W(`WTBUF_DEPTH_W),
               .L2_WTBUF_DEPTH_W(`WTBUF_DEPTH_W),
               .CTRL_CNT(0)
               
               )
   cache (
	  .clk (clk),
	  .reset (reset),
	  .wdata (wdata),
	  .addr  ({select, addr}),
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
   
`else // !`ifdef L2
 `ifdef AXI  
   iob_cache_axi #(
                   .FE_ADDR_W(`ADDR_W),
                   .FE_DATA_W(`DATA_W),
                   .N_WAYS(`N_WAYS),
                   .LINE_OFF_W(`LINE_OFF_W),
                   .WORD_OFF_W(`WORD_OFF_W),
                   .BE_ADDR_W(`MEM_ADDR_W),
                   .BE_DATA_W(`MEM_DATA_W),
                   .REP_POLICY(`REP_POLICY),
  `ifdef LA
                   .LA_INTERF(1),
  `else
                   .LA_INTERF(0),
  `endif
  `ifdef NO_CTRL
                   .CTRL_CACHE(0),
  `endif
                   .WTBUF_DEPTH_W(`WTBUF_DEPTH_W)
                   )
   cache (
	  .clk (clk),
	  .reset (reset),
	  .wdata (wdata),
	  .addr  ({select, addr}),
	  .wstrb (wstrb),
	  .rdata (rdata),
	  .valid (valid),
	  .ready (ready),
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
          .axi_rdata(axi_rdata), 
          .axi_rresp(axi_rresp), 
          .axi_rlast(axi_rlast), 
          .axi_rvalid(axi_rvalid),  
          .axi_rready(axi_rready)
	  );

   
 `else // !`ifdef AXI
   
   iob_cache #(
               .FE_ADDR_W(`ADDR_W),
               .FE_DATA_W(`DATA_W),
               .N_WAYS(`N_WAYS),
               .LINE_OFF_W(`LINE_OFF_W),
               .WORD_OFF_W(`WORD_OFF_W),
               .BE_ADDR_W(`MEM_ADDR_W),
               .BE_DATA_W(`MEM_DATA_W),
               .REP_POLICY(`REP_POLICY),

  `ifdef NO_CTRL
               .CTRL_CACHE(0),
  `endif
               .WTBUF_DEPTH_W(`WTBUF_DEPTH_W)
               )
   cache (
	  .clk (clk),
	  .reset (reset),
	  .wdata (wdata),
	  .addr  ({select, addr}),
	  .wstrb (wstrb),
	  .rdata (rdata),
	  .valid (valid),
	  .ready (ready),
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

   
 `endif // !`ifdef AXI
   
   
`endif // !`ifdef L2
   
   

   task cache_wait;
      input ready;
      begin
         wait (ready == 1'b1);
         #1;
      end
   endtask
   
   
`ifdef AXI  
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

`else

   iob_sp_ram #(
		.DATA_W (`MEM_DATA_W),
                .ADDR_W(`MEM_ADDR_W-2)
                )
   native_ram
     (
      .clk(clk),
      .en  (mem_valid),
      .we  (mem_wstrb),
      .addr(mem_addr[`MEM_ADDR_W-1:$clog2(`MEM_DATA_W/8)]),
      .data_out(mem_rdata),
      .data_in (mem_wdata)
      );

   always @(posedge clk)
     mem_ready <= mem_valid;
   
   
`endif

endmodule // iob_cache_tb


