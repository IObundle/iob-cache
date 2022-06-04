`timescale 1ns/10ps

`include "iob_cache.vh"
`include "iob_cache_conf.vh"

module iob_cache_tb;

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

   iob_cache_wrapper 
     #(
       .ADDR_W(`ADDR_W),
       .DATA_W(`DATA_W),
       .BE_ADDR_W(`BE_ADDR_W),
       .BE_DATA_W(`BE_DATA_W)
       )
   iob_cache_wrapper0
     (
      .clk(clk),
      .reset(reset),

      .req(req),
      .addr({ctrl, addr}),
      .wdata(wdata),
      .wstrb(wstrb),
      .rdata(rdata),
      .ack(ack)
      );
   
endmodule


