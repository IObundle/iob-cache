`timescale 1ns / 10ps
`include "iob_utils.vh"
`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_tb;

   localparam ADDR_W = `IOB_CACHE_ADDR_W;
   localparam DATA_W = `IOB_CACHE_DATA_W;
   
   //global reset
   reg rst = 0;
   reg arst = 0;
   reg cke_i = 0;

   //clock
   `IOB_CLOCK(clk, CLK_PER)

   //system async reset, sync de-assert
   always @(posedge clk, posedge rst) begin
      if (rst) begin 
         arst = 1;
      end else begin 
         arst = #1 rst;
      end
   end

   //control signals
`include "iob_m_tb_wire.vs"


localparam FE_ADDR_W = `IOB_CACHE_FE_ADDR_W;
localparam FE_DATA_W = `IOB_CACHE_FE_DATA_W;
localparam BE_ADDR_W = `IOB_CACHE_BE_ADDR_W;
localparam BE_DATA_W = `IOB_CACHE_BE_DATA_W;
   
   //frontend signals
   reg     [                1-1:0] fe_iob_avalid_i = 0;  //Request valid.
   reg     [           FE_ADDR_W-1:0] fe_iob_addr_i = 0;  //Address.
   reg     [           FE_DATA_W-1:0] fe_iob_wdata_i = 0;  //Write data.
   reg     [       (FE_DATA_W/8)-1:0] fe_iob_wstrb_i = 0;  //Write strobe.
   wire    [                1-1:0] fe_iob_rvalid_o;  //Read data valid.
   wire    [           FE_DATA_W-1:0] fe_iob_rdata_o;  //Read data.
   wire    [                1-1:0] fe_iob_ready_o;  //Interface ready.

   
   //backend signals
   wire    [                1-1:0] be_iob_avalid_o;  //Request valid.
   wire    [           BE_ADDR_W-1:0] be_iob_addr_o;  //Address.
   wire    [           BE_DATA_W-1:0] be_iob_wdata_o;  //Write data.
   wire    [       (BE_DATA_W/8)-1:0] be_iob_wstrb_o;  //Write strobe.
   reg     [                1-1:0] be_iob_rvalid_i = 0;  //Read data valid.
   reg     [           BE_DATA_W-1:0] be_iob_rdata_i = 0;  //Read data.
   reg     [                1-1:0] be_iob_ready_i = 0;  //Interface ready.


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

 `include "iob_s_s_portmap.vs"
      //front-end
      .fe_iob_avalid_i(fe_iob_avalid[0+:1]),          //Request valid.
      .fe_iob_addr_i  (fe_iob_addr[0+:FE_ADDR_W]),       //Address.
      .fe_iob_wdata_i (fe_iob_wdata[0+:FE_DATA_W]),      //Write data.
      .fe_iob_wstrb_i (fe_iob_wstrb[0+:(FE_DATA_W/8)]),  //Write strobe.
      .fe_iob_rvalid_o(fe_iob_rvalid[0+:1]),          //Read data valid.
      .fe_iob_rdata_o (fe_iob_rdata[0+:FE_DATA_W]),      //Read data.
      .fe_iob_ready_o (fe_iob_ready[0+:1]),           //Interface ready.

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
 `include "iob_s_s_portmap.vs"
      //front-end
      .fe_iob_avalid_i(fe_iob_avalid_i),          //Request valid.
      .fe_iob_addr_i  (fe_iob_addr_i),       //Address.
      .fe_iob_wdata_i (fe_iob_wdata_i),      //Write data.
      .fe_iob_wstrb_i (fe_iob_wstrb_i),  //Write strobe.
      .fe_iob_rvalid_o(fe_iob_rvalid_o),          //Read data valid.
      .fe_iob_rdata_o (fe_iob_rdata_o),      //Read data.
      .fe_iob_ready_o (fe_iob_ready_o),           //Interface ready.

      .be_iob_avalid_o(be_iob_avalid[0+:1]),          //Request valid.
      .be_iob_addr_o  (be_iob_addr[0+:BE_ADDR_W]),       //Address.
      .be_iob_wdata_o (be_iob_wdata[0+:BE_DATA_W]),      //Write data.
      .be_iob_wstrb_o (be_iob_wstrb[0+:(BE_DATA_W/8)]),  //Write strobe.
      .be_iob_rvalid_i(be_iob_rvalid[0+:1]),          //Read data valid.
      .be_iob_rdata_i (be_iob_rdata[0+:BE_DATA_W]),      //Read data.
      .be_iob_ready_i (be_iob_ready[0+:1]),           //Interface ready.

  .clk_i(clk),
    .arst_i(arst),
    .cke_i(cke_i)
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
      .en_i  (be_iob_avalid_o),
      .addr_i(be_iob_addr_o),
      .d_i   (be_iob_wdata_o),
      .we_i  (be_iob_wstrb_o),
      .d_o   (be_iob_rdata_i)
   );

   always @(posedge clk, posedge arst) begin
      if (arst) begin
         be_iob_rvalid_i <= 1'b0;
      end else begin
         be_iob_rvalid_i <= be_iob_valid_i;
      end
   end

   assign be_iob_ready_i = 1'b1;
   
`endif

endmodule

