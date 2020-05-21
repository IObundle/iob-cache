`timescale 1ns/10ps

`include "rep_pol_tb.vh"

module rep_pol_tb;

   reg clk = 1;
   always #1 clk = ~clk;
   reg reset = 1;
   
   reg [`N_WAYS-1:0] way_hit = 0;
   reg [$clog2(`N_WAYS) -1:0] way_select;
   reg                        write_en = 0;
   reg [31:0]                 test = 0;
   wire [`N_WAYS -1:0]        way_select_bin = 1 << way_select;
   reg [$clog2(`N_WAYS) :0] random = `LFSR_IN; // linear-feedback-shift-register for random number generation
   wire [`N_WAYS -1:0]        way_random_bin = 1 << random[$clog2(`N_WAYS):1];
                     

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
        $display("\nInitializing Cache's Replacement Policy testing!\nThe results will be printed and the user must check if the replacement policy is working as predicted");
        $display("Test 1 - Only cache misses - %d iterations\n", `N_CYCLES*`N_WAYS);
        test <= 1;
        for (i = 0; i < (`N_CYCLES*`N_WAYS); i = i + 1)
          begin
             #4;
             $display("%d: %b", i,way_select_bin);
             way_hit <= 1 << way_select;
             #2;
             write_en <= 1;
             #2;
             write_en <= 0;
          end
        

        $display("\nTest 2 - Replacement Policy behaviour with random hits\n");
        test <= 2;
        for (i = 0; i < (`N_CYCLES*`N_WAYS); i = i + 1)
          begin
             $display("%d:", i);
             $display("- way-hit:    %b  ", way_random_bin);
             way_hit <= 1<<random;
             #2;
             write_en <= 1;
             #2;
             write_en <= 0;
             #4;
             $display("- way-select: %b\n", way_select_bin);
             #2;
          end
        $display("Replacement Policy testing completed\n");
        $finish;
     end      

        replacement_process #(
	                              .N_WAYS    (`N_WAYS    ),
	                              .LINE_OFF_W(0         ),
                                      .REP_POLICY(`REP_POLICY)
	                              )
                replacement_policy_algorithm
                  (
                   .clk       (clk       ),
                   .reset     (reset     ),
                   .write_en  (write_en  ),
                   .way_hit   (way_hit   ),
                   .line_addr (1'b0      ),
                   .way_select(way_select)
                   );
     
   genvar f;
   
   //Linear-Feedback-Shift-Register - Random signal generator
   generate
      for (f = 1; f < $clog2(`N_WAYS); f = f + 1)
        begin
           always @(posedge clk)
             random [f] <= random [f-1];
        end
   endgenerate
   
   always @(posedge clk)
             random [0] <= random[$clog2(`N_WAYS)-1] ^ random[$clog2(`N_WAYS)-2];
      
endmodule // rep_pol_tb


