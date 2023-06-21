`timescale 1ns / 10ps
`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"
`include "iob_utils.vh"

module iob_cache_tb;

   //global reset
   reg [1-1:0] rst = 0;

   //clock
   `IOB_CLOCK(clk, CLK_PER)

   //system async reset, sync de-assert
   reg [1-1:0] arst = 0;
   always @(posedge clk, posedge rst) begin
      if (rst) begin 
         arst = 1;
      end else begin 
         arst = #1 rst;
      end
   end

   //frontend signals
   reg                                                    fe_req = 0;
   wire                                                   fe_ack;
   reg [`IOB_CACHE_FE_ADDR_W-1:0]                         addr = 0;
   reg [                          `IOB_CACHE_FE_DATA_W-1:0] fe_wdata = 0;
   reg [                        `IOB_CACHE_FE_DATA_W/8-1:0] wstrb = 0;
   wire [                          `IOB_CACHE_FE_DATA_W-1:0] rdata;

   //control signals
   reg [1-1:0]                                               ctrl_req = 0;
   reg [`IOB_CACHE_ADDR_W-1:0]                               ctrl_addr = 0;
   reg [1-1:0]                                               ctrl_wstrb = 0;
   reg [`IOB_CACHE_DATA_W-1:0]                               ctrl_wdata = 0;
   wire [`IOB_CACHE_DATA_W-1:0]                              ctrl_rdata = 0;
   wire [1-1:0]                                              ctrl_ack;
   
   reg                                                       `IOB_CACHE_DATA_W-1:0] data;

   //file descriptor
   integer fd;
   
   //iterator
   integer i;

   //test process
   initial begin
`ifdef VCD
      $dumpfile("uut.vcd");
      $dumpvars();
`endif

      fd = $fopen("test.log", "w");

      //core hard reset (loads default configuration)
      #10 `IOB_PULSE(rst, 50, 50, 50)

      for (i = 0; i < 10; i=i+1) begin
         iob_write(i, i, `IOB_CACHE_FE_DATA_W);
      end
      for (i = 0; i < 10; i=i+1) begin
         iob_read(i, data, `IOB_CACHE_FE_DATA_W);
         if (data != i) begin
            $display("ERROR: read data mismatch");
            $fwrite(fd, "Test failed!\n");
            $fatal(1);
         end
      end

      $display("Test passed!");
      $fwrite(fd, "Test passed!\n");
      $fclose(fd);
   end

   //Unit Under Test (simulation wrapper)
   iob_cache_sim_wrapper uut (
      .clk_i(clk),
      .rst_i(rst),
                              //control signals
      .ctrl_req_i(ctrl_req),
      .ctrl_addr_i(ctrl_addr),
      .ctrl_wstrb_i(ctrl_wstrb),
      .ctrl_wdata_i(ctrl_wdata),
      .ctrl_rdata_o(ctrl_rdata),
      .ctrl_ack_o(ctrl_ack),
                              //frontend signals
                              
      .fe_req  (fe_req),
      .fe_addr (fe_addr),
      .fe_wdata(fe_wdata),
      .fe_wstrb(fe_wstrb),
      .fe_rdata(fe_rdata),
      .fe_ack  (fe_ack),


   );

   `include "iob_tasks.vs"

endmodule

