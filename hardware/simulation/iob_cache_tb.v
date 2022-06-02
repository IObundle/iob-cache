`timescale 1ns/10ps

`include "iob_cache.vh"
`include "iob_cache_conf.vh"

`define AXI  //use AXI4 back-end interface

module iob_cache_tb;

   //AXI4 parameters to use generated wires
   localparam AXI_ADDR_W = `BE_ADDR_W;
   localparam AXI_DATA_W = `BE_DATA_W;
   

   //clock                        
   reg clk = 1;
   always #1 clk = ~clk;
   reg reset = 1;
   
   //iob-native bus signals
   reg                                 req=0;
   wire                                ack;
   reg [`ADDR_W-1:$clog2(`DATA_W/8)]   addr =0;
   reg [`DATA_W-1:0]                   wdata=0;
   reg [`DATA_W/8-1:0]                 wstrb=0;
   wire [`DATA_W-1:0]                  rdata;
   reg                                 ctrl =0;

   reg [31:0]                          test = 0;

   integer                             i,j;

   
   initial 
     begin
        
`ifdef VCD
	$dumpfile("uut.vcd");
	$dumpvars();
`endif  
        repeat (5) @(posedge clk);
        reset = 0;
        #10;
        
        $display("\nInitializing Cache testing - check simulation results\n");
        $display("Test 1 - Writing test\n");
        test = 1;
        req = 1;
        addr = 0;
        wdata = 0;
        wstrb = {`DATA_W/8{1'b1}};
        #2;
        
        for (i = 1; i < 10; i = i + 1)
          begin
             //wstrb = {`DATA_W/8{1'b1}};
             addr = i;
             wdata =  i;
             #2
               while (!ack)#2;
             
          end // for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
        req = 0;
        #80;
        
        $display("Test 2 - Reading Test\n");
        test = 2;
        addr = 0;
        wdata = 2880291038;
        wstrb = 0;
        req = 1;
        #2;
        for (j = 1; j < 10; j = j + 1)
          begin
             addr = j;
             #2
               while (!ack) #2;  
          end // for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
        req =0;
        addr = 0;
        #20;



        $display("Test 3 - Writing (write-hit) test\n");
        test = 3;
        addr = 0;
        wdata = 10;
        wstrb = {`DATA_W/8{1'b1}};
        req = 1;
        // #2;
        // req = 0;
        
        #2;
        for (i = 1; i < 11; i = i + 1)
          begin
             addr = i;
             wdata =  i + 10;
             #2;
             
             while (!ack) #2;
          end // for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
        req = 0;
        addr =0;
        #80;
        
        $display("Test 4 - Testing RAW control (r-w-r)\n");
        test = 4;
        addr = 0;
        req =1;
        wstrb =0;
        #2;
        while (!ack) #2;
        wstrb = {`DATA_W/8{1'b1}};
        wdata = 57005;
        #2;
        wstrb = 0;
        #2
          while (!ack) #2;
        req = 0;
        #80;
        
        $display("Test 5 - Test Line Replacement with read the last written position\n");
        test = 5;
        addr = (2**`WORD_OFFSET_W)*5-1;
        req = 1;
        wstrb = {`DATA_W/8{1'b1}};
        wdata = 3735928559;
        #2;
        while (!ack) #2;
        req = 0;
        wstrb = 0;
        while (!ack) #2;
        req = 0;
        #80;



        $display("Test 6 - Testing RAW on different positions (r-w-r)\n");
        test = 6;
        addr = 0;
        req =1;
        wstrb =0;
        #20
          wstrb = {`DATA_W/8{1'b1}};
        wdata = 23434332205;
        #2;
        addr = 1; //change of addr
        wstrb = 0;
        #2
          while (!ack) #2;
        req = 0;
        #80;

        
        $display("Test 7 - Testing cache-invalidate (r-inv-r)\n");
        test = 7;
        addr = 0;
        req =1;
        wstrb =0;
        while (!ack) #2;
        ctrl =1;  //ctrl function
        addr = 10;//invalidate
        req =1;
        #2;
        while (!ack) #2;
        ctrl =0;
        addr =0;
        #80;
        $display("Cache testing completed\n");
        $finish;
     end // initial begin


   
`ifdef AXI
`include "iob_cache_axi_wire.vh"
`else
   //Native connections
   wire [`BE_ADDR_W-1:0]           mem_addr;
   wire [`BE_DATA_W-1:0]           mem_wdata, mem_rdata;
   wire [`BE_N_BYTES-1:0]          mem_wstrb;
   wire                            mem_req;
   reg                             mem_ack;
   
`endif  

`ifdef AXI   
   iob_cache_axi
`else
   iob_cache
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
   cache
`endif     
      (
      //front-end
      .wdata (wdata),
      .addr  ({ctrl, addr}),
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
      .mem_addr(mem_addr),
      .mem_wdata(mem_wdata),
      .mem_wstrb(mem_wstrb),
      .mem_rdata(mem_rdata),
      .mem_req(mem_req),
      .mem_ack(mem_ack),
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

   iob_sp_ram_be 
     #(
       .NUM_COL(`BE_N_BYTES),
       .COL_W(8),
       .ADDR_W(`BE_ADDR_W-2)
       )
   native_ram
     (
      .clk(clk),
      .en  (mem_req),
      .we  (mem_wstrb),
      .addr(mem_addr[`BE_ADDR_W-1:$clog2(`BE_DATA_W/8)]),
      .dout(mem_rdata),
      .din (mem_wdata)
      );
   
   always @(posedge clk)
     mem_ack <= mem_req;
   
`endif

endmodule


