`timescale 1ns/10ps

`include "iob_cache.vh"

module iob_cache_tb;

   //clock                        
   parameter clk_per = 10;
   reg clk = 1;
   always #clk_per clk = ~clk;


   reg reset = 1;
   
   //iob-native bus signals
   reg                                 req=0;
   wire                                ack;
   reg [`ADDR_W-2:$clog2(`DATA_W/8)]   addr =0;
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
        
        $display("\nStart of Cache Testing");
	
        $display("Test 1: Writing Test");
        for(i=0; i<5; i=i+1) begin
	   @(posedge clk) #1 req=1;
	   wstrb={`DATA_W/8{1'b1}};
	   addr=i;
           wdata=i*3;
	   wait(ack); #1 req=0;
	end   

        #80 @(posedge clk);

	$display("Test 2: Reading Test");
        for(i=0; i<5; i=i+1) begin
           @(posedge clk) #1 req=1;
           wstrb={`DATA_W/8{1'b0}};
           addr=i;
           wait(ack); #1 req=0;
	   if(rdata == i*3) $display("\tReading rdata=0x%0h at addr=0x%0h: PASSED", rdata, i);
           else $display("\tReading rdata=0x%0h at addr=0x%0h: FAILED", rdata, i);  
        end

        #100;
        $display("End of Cache Testing\n");
        $finish;
     end
	
        /*test = 1;
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
        wdata = 3434332205;
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
*/	 

   iob_cache_wrapper iob_cache_wrapper0 (
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


/*
 
 The below and old testbench tests replacement policies.
 It should be merged into the above when possible.
 
 
 `timescale 1ns/10ps

`define N_CYCLES 3//Number of cycles of read-misses during simulation
`define N_WAYS 4
`define REP_POLICY 1 // check Replacement Policy
//Linear-Feedback-Shift-Register - Random generator
`define LFSR_IN 5 // input for random-value generator - way-hit

module rep_pol_tb;

   reg clk = 1;
   always #1 clk = ~clk;
   reg reset = 1;
   
   reg [`N_WAYS-1:0] way_hit = 0;
   wire [$clog2(`N_WAYS) -1:0] way_select_bin;
   reg                        write_en = 0;
   reg [31:0]                 test = 0;
   wire [`N_WAYS -1:0]        way_select;

   // linear-feedback-shift-register for random number generation
   reg [31 :0]                random = `LFSR_IN;
   reg [$clog2(`N_WAYS) :0] random_sel; //store random singal in a specific period
   wire [`N_WAYS -1:0]        way_random_bin = 1 << random_sel[$clog2(`N_WAYS):1];

   integer                            i,j;
   
   initial 
     begin
        
`ifdef VCD
	$dumpfile("rep_pol.vcd");
	$dumpvars();
`endif  
        repeat (5) @(posedge clk);
        reset <= 0;
        #10;
        for (i = 0; i < (`N_WAYS); i = i + 1) //to avoid simulations "Unknowns" with the one-hot to binary encoders
          begin
             way_hit <= i;
             #4;
          end
        $display("\nInitializing Cache's Replacement Policy testing!\nThe results will be printed and the user must check if the replacement policy is working as predicted");
        $display("Test 1 - Only cache misses - %d iterations\n",`N_WAYS);
        test <= 1;
        for (i = 0; i < (`N_WAYS); i = i + 1)
          begin
             #4;
             $display("%d: %b", i,way_select);
             way_hit <= way_select;
             #2;
             write_en <= 1;
             #2;
             write_en <= 0;
          end
        #10;
        reset <= 1'b1;
        #2;
        reset <= 1'b0;
        #2;
        $display("\nTest 2 - Replacement Policy behaviour with random hits\n");
        test <= 2;
        for (i = 0; i < (`N_CYCLES*`N_WAYS); i = i + 1)
          begin
             #6;
             random_sel <= random;
             #2;
             $display("%d:", i);
             $display("- way-hit:    %b  ", way_random_bin);
             way_hit <= way_random_bin;
             #2;
             write_en <= 1;
             #2;
             write_en <= 0;
             #6;
             $display("- way-select: %b\n", way_select);
             #2;
          end
         
         
        $display("Replacement Policy testing completed\n");
        $finish;
     end      

   replacement_policy 
     #(
       .N_WAYS (`N_WAYS),
       .NLINES_W (0),
       .REP_POLICY (`REP_POLICY)
       )
   replacement_policy0
     (
      .clk (clk),
      .reset (reset),
      .write_en (write_en),
      .way_hit (way_hit),
      .line_addr (1'b0),
      .way_select (way_select),
      .way_select_bin (way_select_bin)
      );
     
   genvar f;
   
   //Linear-Feedback-Shift-Register - Random signal generator
   generate
      for (f = 1; f < 32; f = f + 1)
        begin
           always @(posedge clk)
             random [f] <= random [f-1];
        end
   endgenerate
   
   always @(posedge clk)
             random [0] <= random[31] ^ random[28]; //PSRB31 = x^31 + x^28 + 1
      
endmodule // rep_pol_tb



 */
