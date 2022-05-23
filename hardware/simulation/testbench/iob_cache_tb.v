`timescale 1ns/10ps

`include "iob_cache.vh"
`include "iob_cache_conf.vh"

`define AXI //use AXI4 back-end interface

module iob_cache_tb;

   //parameters needed by macros
   localparam BE_DATA_W = `BE_DATA_W;
   

   //clock                        
   reg clk = 1;
   always #1 clk = ~clk;
   reg reset = 1;
   
   //native bus signals
   reg                                 req=0;
   wire                                ack;
   reg [`ADDR_W-1  :$clog2(`DATA_W/8)] addr =0;
   reg [`DATA_W-1:0]                   wdata=0;
   reg [`DATA_W/8-1:0]                 wstrb=0;
   wire [`DATA_W-1:0]                  rdata;
   reg                                 ctrl =0;

   wire                                i_select =0, d_select =0;
   reg [31:0]                          test = 0;
   reg                                 pipe_en = 0;
   

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
   wire                            mem_valid;
   reg                             mem_ready;
   
`endif  
   
   reg                             cpu_state;

   reg [`ADDR_W-1  :$clog2(`DATA_W/8)] cpu_addr;
   reg [`DATA_W-1:0]                   cpu_wdata;
   reg [`DATA_W/8-1:0]                 cpu_wstrb;
   reg                                 cpu_req;

   
   

   iob_cache_axi
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
   cache 
     (
      //front-end
      .wdata (cpu_wdata),
      .addr  ({ctrl,cpu_addr}),
      .wstrb (cpu_wstrb),
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
  `include "iob_cache_iob_cache_axi_portmap.vh"
`else
      .mem_addr(mem_addr),
      .mem_wdata(mem_wdata),
      .mem_wstrb(mem_wstrb),
      .mem_rdata(mem_rdata),
      .mem_valid(mem_valid),
      .mem_ready(mem_ready),
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
      .s_axi_awid     (iob_cache_axi_awid),
      .s_axi_awaddr   (iob_cache_axi_awaddr),
      .s_axi_awlen    (iob_cache_axi_awlen),
      .s_axi_awsize   (iob_cache_axi_awsize),
      .s_axi_awburst  (iob_cache_axi_awburst),
      .s_axi_awlock   (iob_cache_axi_awlock),
      .s_axi_awprot   (iob_cache_axi_awprot),
      .s_axi_awcache  (iob_cache_axi_awcache),
      .s_axi_awvalid  (iob_cache_axi_awvalid),
      .s_axi_awready  (iob_cache_axi_awready),
      
      //write  
      .s_axi_wvalid   (iob_cache_axi_wvalid),
      .s_axi_wready   (iob_cache_axi_wready),
      .s_axi_wdata    (iob_cache_axi_wdata),
      .s_axi_wstrb    (iob_cache_axi_wstrb),
      .s_axi_wlast    (iob_cache_axi_wlast),
      
      //write response
      .s_axi_bready   (iob_cache_axi_bready),
      .s_axi_bid      (iob_cache_axi_bid),
      .s_axi_bresp    (iob_cache_axi_bresp),
      .s_axi_bvalid   (iob_cache_axi_bvalid),
      
      //address read
      .s_axi_arid     (iob_cache_axi_arid),
      .s_axi_araddr   (iob_cache_axi_araddr),
      .s_axi_arlen    (iob_cache_axi_arlen), 
      .s_axi_arsize   (iob_cache_axi_arsize),    
      .s_axi_arburst  (iob_cache_axi_arburst),
      .s_axi_arlock   (iob_cache_axi_arlock),
      .s_axi_arcache  (iob_cache_axi_arcache),
      .s_axi_arprot   (iob_cache_axi_arprot),
      .s_axi_arvalid  (iob_cache_axi_arvalid),
      .s_axi_arready  (iob_cache_axi_arready),
      
      //read   
      .s_axi_rready   (iob_cache_axi_rready),
      .s_axi_rid      (iob_cache_axi_rid),
      .s_axi_rdata    (iob_cache_axi_rdata),
      .s_axi_rresp    (iob_cache_axi_rresp),
      .s_axi_rlast    (iob_cache_axi_rlast),
      .s_axi_rvalid   (iob_cache_axi_rvalid)
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
      .en  (mem_valid),
      .we  (mem_wstrb),
      .addr(mem_addr[`BE_ADDR_W-1:$clog2(`BE_DATA_W/8)]),
      .dout(mem_rdata),
      .din (mem_wdata)
      );
   
   always @(posedge clk)
     mem_ready <= mem_valid;
   
`endif

endmodule // iob_cache_tb


