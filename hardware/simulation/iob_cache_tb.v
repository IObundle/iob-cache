`timescale 1ns/10ps
`include "iob_cache_conf.vh"

module iob_cache_tb;

   //clock                        
   parameter clk_per = 10;
   reg clk = 1;
   always #clk_per clk = ~clk;


   reg reset = 1;
   
   //frontend signals
   reg req=0;
   wire ack;
   reg [`IOB_CACHE_ADDR_W-2:$clog2(`IOB_CACHE_DATA_W/8)] addr =0;
   reg [`IOB_CACHE_DATA_W-1:0]                           wdata=0;
   reg [`IOB_CACHE_DATA_W/8-1:0]                         wstrb=0;
   wire [`IOB_CACHE_DATA_W-1:0]                          rdata;
   reg                                                   ctrl =0;

   //backend signals
`ifdef AXI
 `include "iob_cache_axi_wire.vh"
`else
   //Native connections
   wire [`IOB_CACHE_BE_ADDR_W-1:0]                       be_addr;
   wire [`IOB_CACHE_BE_DATA_W-1:0]                       be_wdata, be_rdata;
   wire [`IOB_CACHE_BE_DATA_W/8-1:0]                     be_wstrb;
   wire                                                  be_req;
   reg                                                   be_ack;
`endif  
   
   reg [31:0]                                            test = 0;
   integer                                               i,j;

   
   initial begin
      
`ifdef VCD
      $dumpfile("uut.vcd");
      $dumpvars();
`endif  
      repeat (5) @(posedge clk);
      reset = 0;
      #10;

      $display("Test 1: Writing Test");
      for(i=0; i<5; i=i+1) begin
	 @(posedge clk) #1 req=1;
	 wstrb={`IOB_CACHE_DATA_W/8{1'b1}};
	 addr=i;
         wdata=i*3;
	 wait(ack); #1 req=0;
      end   
      
      #80 @(posedge clk);

      $display("Test 2: Reading Test");
      for(i=0; i<5; i=i+1) begin
         @(posedge clk) #1 req=1;
         wstrb={`IOB_CACHE_DATA_W/8{1'b0}};
         addr=i;
         wait(ack); #1 req=0;
	 if(rdata == i*3) $display("\tReading rdata=0x%0h at addr=0x%0h: PASSED", rdata, i);
         else $display("\tReading rdata=0x%0h at addr=0x%0h: FAILED", rdata, i);  
      end
      
      #100;
      $display("End of Cache Testing\n");
      $finish;
   end
   
   iob_cache iob_cache0 
     (
      //frontend 
      .req   (req),
      .addr  ({ctrl, addr}),
      .wdata (wdata),
      .wstrb (wstrb),
      .rdata (rdata),
      .ack   (ack),


     //invalidate / wtb empty
      .invalidate_in(1'b0),
      .invalidate_out(),
      .wtb_empty_in(1'b1),
      .wtb_empty_out(),

      //backend 
`ifdef AXI
 `include "iob_cache_axi_portmap.vh"
`else
      .be_req   (be_req),
      .be_addr  (be_addr),
      .be_wdata (be_wdata),
      .be_wstrb (be_wstrb),
      .be_rdata (be_rdata),
      .be_ack   (be_ack),
`endif
      .clk(clk),
      .rst(reset)
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
 `include "iob_cache_ram_axi_portmap.vh"
      .clk            (clk),
      .rst            (reset)
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
`endif

   initial begin
`ifdef AXI
      $display("\nTesting Cache with AXI4 Backend");
`else
      $display("\nTesting Cache with IOB Backend");
`endif
   end

   
endmodule

