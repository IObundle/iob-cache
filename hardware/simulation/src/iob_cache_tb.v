`timescale 1ns / 10ps
`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"
`include "iob_utils.vh"

module iob_cache_tb;

   localparam ADDR_W = `IOB_CACHE_ADDR_W;
   localparam DATA_W = `IOB_CACHE_DATA_W;
   
   //global reset
   reg rst = 0;
   reg arst_i;

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
   reg [`IOB_CACHE_FE_ADDR_W-1:0]                         fe_addr = 0;
   reg [                          `IOB_CACHE_FE_DATA_W-1:0] fe_wdata = 0;
   reg [                        `IOB_CACHE_FE_DATA_W/8-1:0] fe_wstrb = 0;
   wire [                          `IOB_CACHE_FE_DATA_W-1:0] fe_rdata;

   //control signals
`include "iob_m_tb_wire.vs"
   
   reg [`IOB_CACHE_DATA_W-1:0]                               data;

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

`include "iob_tasks.vs"

   //
   // cache
   //
`ifdef AXI
   iob_cache_axi cache (
                        //front-end
      .wdata(fe_wdata),
      .addr (fe_addr),
      .wstrb(fe_wstrb),
      .rdata(fe_rdata),
      .req  (fe_req),
      .ack  (fe_ack),

      //invalidate / wtb empty
      .invalidate_in (1'b0),
      .invalidate_out(),
      .wtb_empty_in  (1'b1),
      .wtb_empty_out (),

      `include "iob_axi_m_m_portmap.vs"

      //general
      .clk_i(clk),
      .rst_i(arst)
   );
`else
   wire                   be_req;
   reg                    be_ack;
   wire [  `IOB_CACHE_BE_ADDR_W-1:0] be_addr;
   wire [  `IOB_CACHE_BE_DATA_W-1:0] be_wdata;
   wire [`IOB_CACHE_BE_DATA_W/8-1:0] be_wstrb;
   wire [  `IOB_CACHE_BE_DATA_W-1:0] be_rdata;

   iob_cache_iob cache (
                        //control
                        `include "iob_s_portmap.vs"
      //front-end
      .wdata(fe_wdata),
      .addr (fe_addr),
      .wstrb(fe_wstrb),
      .rdata(fe_rdata),
      .req  (fe_req),
      .ack  (fe_ack),

      //invalidate / wtb empty
      .invalidate_in (1'b0),
      .invalidate_out(),
      .wtb_empty_in  (1'b1),
      .wtb_empty_out (),

      .be_addr (be_addr),
      .be_wdata(be_wdata),
      .be_wstrb(be_wstrb),
      .be_rdata(be_rdata),
      .be_req  (be_req),
      .be_ack  (be_ack),

      .clk_i(clk),
      .rst_i(arst)
   );
`endif

   //
   //system memory
   //
`ifdef AXI
   axi_ram #(
      .ID_WIDTH  (`IOB_CACHE_AXI_ID_W),
      .LEN_WIDTH (`IOB_CACHE_AXI_LEN_W),
      .DATA_WIDTH(`IOB_CACHE_BE_DATA_W),
      .ADDR_WIDTH(`IOB_CACHE_BE_ADDR_W)
   ) axi_ram (
 `include "iob_axi_s_portmap.vs"
      .clk(clk),
      .rst(arst)
   );
`else
   iob_ram_sp_be #(
      .DATA_W(`IOB_CACHE_BE_DATA_W),
      .ADDR_W(`IOB_CACHE_BE_ADDR_W)
   ) native_ram (
      .clk_i (clk),
      .en_i  (be_req),
      .we_i  (be_wstrb),
      .addr_i(be_addr),
      .d_o   (be_rdata),
      .d_i   (be_wdata)
   );

   always @(posedge clk, posedge arst) begin
      if (arst) begin
         be_ack <= 1'b0;
      end else begin
         be_ack <= be_req;
      end
   end
`endif

endmodule

