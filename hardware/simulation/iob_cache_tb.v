`timescale 1ns / 10ps
`include "iob_cache_conf.vh"

module iob_cache_tb;

   //clock
   parameter clk_per = 10;
   reg clk = 1;
   always #clk_per clk = ~clk;


   reg                                                    rst = 1;

   //frontend signals
   reg                                                    req = 0;
   wire                                                   ack;
   reg  [`IOB_CACHE_ADDR_W-2:$clog2(`IOB_CACHE_DATA_W/8)] addr = 0;
   reg  [                          `IOB_CACHE_DATA_W-1:0] wdata = 0;
   reg  [                        `IOB_CACHE_DATA_W/8-1:0] wstrb = 0;
   wire [                          `IOB_CACHE_DATA_W-1:0] rdata;
   reg                                                    ctrl = 0;

   //iterator
   integer i, fd;

   //test process
   initial begin
`ifdef VCD
      $dumpfile("uut.vcd");
      $dumpvars();
`endif
      repeat (5) @(posedge clk);
      rst = 0;
      #10;

      $display("Test 1: Writing Test");
      for (i = 0; i < 5; i = i + 1) begin
         @(posedge clk) #1 req = 1;
         wstrb = {`IOB_CACHE_DATA_W / 8{1'b1}};
         addr  = i;
         wdata = i * 3;
         wait (ack);
         #1 req = 0;
      end

      #80 @(posedge clk);

      $display("Test 2: Reading Test");
      for (i = 0; i < 5; i = i + 1) begin
         @(posedge clk) #1 req = 1;
         wstrb = {`IOB_CACHE_DATA_W / 8{1'b0}};
         addr  = i;
         wait (ack);
         #1 req = 0;
         //Write "Test passed!" to a file named "test.log"
         if (rdata == i * 3) $display("\tReading rdata=0x%0h at addr=0x%0h: PASSED", rdata, i);
         else begin
            $display("\tReading rdata=0x%0h at addr=0x%0h: FAILED", rdata, i);
            fd = $fopen("test.log", "w");
            $fdisplay(fd, "Test failed!\nReading rdata=0x%0h at addr=0x%0h: FAILED", rdata, i);
            $fclose(fd);
            $finish();
         end
      end

      #100;
      $display("End of Cache Testing\n");
      fd = $fopen("test.log", "w");
      $fwrite(fd, "Test passed!");
      $fclose(fd);
      $finish();
   end

   //Unit Under Test (simulation wrapper)
   iob_cache_sim_wrapper uut (
      //frontend 
      .req  (req),
      .addr ({ctrl, addr}),
      .wdata(wdata),
      .wstrb(wstrb),
      .rdata(rdata),
      .ack  (ack),


      //invalidate / wtb empty
      .invalidate_in (1'b0),
      .invalidate_out(),
      .wtb_empty_in  (1'b1),
      .wtb_empty_out (),

      .clk_i(clk),
      .rst_i(rst)
   );

endmodule

