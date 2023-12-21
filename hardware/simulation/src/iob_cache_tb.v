`timescale 1ns / 10ps
`include "iob_utils.vh"
`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_tb;

   //clock
   parameter clk_per = 10;
   reg clk = 1;
   always #clk_per clk = ~clk;

   parameter FE_ADDR_W    = `IOB_CACHE_FE_ADDR_W;
   parameter FE_DATA_W    = `IOB_CACHE_FE_DATA_W;
   parameter FE_NBYTES    = FE_DATA_W / 8;
   parameter FE_NBYTES_W  = $clog2(FE_NBYTES);
   parameter USE_CTRL     = `IOB_CACHE_USE_CTRL;
   parameter USE_CTRL_CNT = `IOB_CACHE_USE_CTRL_CNT;

   parameter ADDR_W       = USE_CTRL+FE_ADDR_W-FE_NBYTES_W;
   parameter DATA_W       = `IOB_CACHE_DATA_W;

   reg                                       rst = 1;

   //frontend signals
`include "iob_m_tb_wire.vs"
   reg                                       ctrl = 0;

   //iterator
   integer i, fd, failed=0;

   reg [DATA_W-1:0] rdata;
   

   //test process
   initial begin
`ifdef VCD
      $dumpfile("uut.vcd");
      $dumpvars();
`endif
      repeat (5) @(posedge clk);
      rst = 0;
      #10;

      $display("Writing data to frontend");
      for (i = 0; i < 5*4; i = i + 4) begin
         iob_write(i, (3*i), `IOB_CACHE_DATA_W);
      end

      #80 @(posedge clk);

      $display("Reading data from frontend");
      for (i = 0; i < 5*4; i = i + 4) begin
         iob_read(i, rdata, `IOB_CACHE_DATA_W);
         //Write "Test passed!" to a file named "test.log"
         if (rdata !== (3*i)) begin
            $display("ERROR at address %d: got 0x%0h, expected 0x%0h", i, rdata, 3*i);
             failed = failed+1;
         end
      end

      #100;

      fd = $fopen("test.log", "w");

      if (failed == 0) begin
         $display("Test passed!");
         $fwrite(fd, "Test passed!");
      end else begin
         $display("Test failed!");
         $fwrite(fd, "Test failed!");
      end
      $fclose(fd);
      $finish();
   end

   //Unit Under Test (simulation wrapper)
   iob_cache_sim_wrapper uut (
      //frontend
`include "iob_s_s_portmap.vs"
      //invalidate / wtb empty
      .invalidate_i (1'b0),
      .invalidate_o(),
      .wtb_empty_i  (1'b1),
      .wtb_empty_o (),

      .clk_i(clk),
      .arst_i(rst)
   );

`include "iob_tasks.vs"

endmodule

