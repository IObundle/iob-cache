`timescale 1ns/10ps

`include "rep_pol_tb.vh"

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

   replacement_policy #(
	                 .N_WAYS    (`N_WAYS    ),
	                 .LINE_OFF_W(0          ),
                         .REP_POLICY(`REP_POLICY)
	                 )
                replacement_policy_algorithm
                  (
                   .clk       (clk       ),
                   .reset     (reset     ),
                   .write_en  (write_en  ),
                   .way_hit   (way_hit   ),
                   .line_addr (1'b0      ),
                   .way_select(way_select),
                   .way_select_bin(way_select_bin)
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


