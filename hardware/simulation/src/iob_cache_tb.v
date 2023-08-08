`timescale 1ns / 10ps
`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_tb;

   //clock
   parameter clk_per = 10;
   reg clk = 1;
   always #clk_per clk = ~clk;

   parameter ADDR_W       = `IOB_CACHE_ADDR_W;
   parameter DATA_W       = `IOB_CACHE_DATA_W;
   parameter FE_ADDR_W    = `IOB_CACHE_FE_ADDR_W;
   parameter FE_DATA_W    = `IOB_CACHE_FE_DATA_W;
   parameter FE_NBYTES    = FE_DATA_W / 8;
   parameter FE_NBYTES_W  = $clog2(FE_NBYTES);
   parameter USE_CTRL     = `IOB_CACHE_USE_CTRL;
   parameter USE_CTRL_CNT = `IOB_CACHE_USE_CTRL_CNT;

   reg                                       rst = 1;

   //frontend signals
   reg                                       avalid = 0;
   wire                                      ack;
   reg  [USE_CTRL+FE_ADDR_W-FE_NBYTES_W-1:0] addr = 0;
   reg  [                        DATA_W-1:0] wdata = 0;
   reg  [                      DATA_W/8-1:0] wstrb = 0;
   wire [                        DATA_W-1:0] rdata;
   reg                                       ctrl = 0;

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
         @(posedge clk) #1 avalid = 1;
         wstrb = {`IOB_CACHE_DATA_W / 8{1'b1}};
         addr  = i;
         wdata = i * 3;
         wait (ack);
         #1 avalid = 0;
      end

      #80 @(posedge clk);

      $display("Test 2: Reading Test");
      for (i = 0; i < 5; i = i + 1) begin
         @(posedge clk) #1 avalid = 1;
         wstrb = {`IOB_CACHE_DATA_W / 8{1'b0}};
         addr  = i;
         wait (ack);
         #1 avalid = 0;
         //Write "Test passed!" to a file named "test.log"
         if (rdata == i * 3) $display("\tReading rdata=0x%0h at addr=0x%0h: PASSED", rdata, i);
         else begin
            $display("\tReading rdata=0x%0h at addr=0x%0h: FAILED", rdata, i);
            fd = $fopen("test.log", "w");
            $fdisplay(fd, "Test failed!\nReading rdata=0x%0h at addr=0x%0h: FAILED", rdata, i);
            $fclose(fd);
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
      .avalid_i(avalid),
      .addr_i ({ctrl, addr[USE_CTRL+FE_ADDR_W-FE_NBYTES_W-2:0]}),
      .wdata_i(wdata),
      .wstrb_i(wstrb),
      .rdata_o(rdata),
      .ack_o  (ack),


      //invalidate / wtb empty
      .invalidate_i (1'b0),
      .invalidate_o(),
      .wtb_empty_i  (1'b1),
      .wtb_empty_o (),

      .clk_i(clk),
      .arst_i(rst)
   );

endmodule

