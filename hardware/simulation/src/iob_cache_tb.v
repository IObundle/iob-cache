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
   `IOB_CLOCK(clk, 10)

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

localparam ADDR_W = `IOB_CACHE_ADDR_W;
localparam DATA_W = `IOB_CACHE_DATA_W;
localparam BE_ADDR_W = `IOB_CACHE_BE_ADDR_W;
localparam BE_DATA_W = `IOB_CACHE_BE_DATA_W;
   
   //frontend signals
   reg  fe_iob_avalid_i = 0;
   reg     [           ADDR_W-1:0] fe_iob_addr_i = 0;
   reg     [           DATA_W-1:0] fe_iob_wdata_i = 0;
   reg     [       (DATA_W/8)-1:0] fe_iob_wstrb_i = 0;
   wire    [                1-1:0] fe_iob_rvalid_o;
   wire    [           DATA_W-1:0] fe_iob_rdata_o;
   wire    [                1-1:0] fe_iob_ready_o;

   
   //backend signals
   wire be_iob_avalid_o;  //Request valid.
   wire    [           BE_ADDR_W-1:0] be_iob_addr_o;
   wire    [           BE_DATA_W-1:0] be_iob_wdata_o;
   wire    [       (BE_DATA_W/8)-1:0] be_iob_wstrb_o;
   reg    [                1-1:0] be_iob_rvalid_i = 0;
   wire     [           BE_DATA_W-1:0] be_iob_rdata_i = 0;

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
         iob_write(4*i, i, `IOB_CACHE_DATA_W);
      end
      for (i = 0; i < 10; i=i+1) begin
         iob_read(4*i, data, `IOB_CACHE_DATA_W);
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

//
// Tasks for the IOb Native protocol
//

// Write data to IOb Native slave
task iob_write;
   input [ADDR_W-1:0] addr;
   input [DATA_W-1:0] data;
   input [$clog2(DATA_W):0] width;

   begin
      @(posedge clk) #1 fe_iob_avalid_i = 1;  //sync and assign
      fe_iob_addr_i  = `IOB_WORD_ADDR(addr);
      fe_iob_wdata_i = `IOB_GET_WDATA(addr, data);
      fe_iob_wstrb_i = `IOB_GET_WSTRB(addr, width);

      while (!fe_iob_ready_o) #1;

      @(posedge clk) #1 fe_iob_avalid_i = 0;
      fe_iob_wstrb_i = 0;
   end
endtask

// Read data from IOb Native slave
task iob_read;
   input [ADDR_W-1:0] addr;
   output [DATA_W-1:0] data;
   input [$clog2(DATA_W):0] width;

   begin
      @(posedge clk) #1 fe_iob_avalid_i = 1;
      fe_iob_addr_i = `IOB_WORD_ADDR(addr);

      while (!fe_iob_ready_o) #1;
      @(posedge clk) #1 fe_iob_avalid_i = 0;

      while (!iob_rvalid_o) #1;
      data = #1 `IOB_GET_RDATA(addr, fe_iob_rdata_o, width);
   end
endtask

   //
   // cache
   //
`ifdef AXI
   iob_cache_axi cache (

 `include "iob_s_s_portmap.vs"
      //front-end
      .fe_iob_avalid_i(fe_iob_avalid_i),
      .fe_iob_addr_i  (fe_iob_addr_i[ADDR_W-1:$clog2(DATA_W/8)]),
      .fe_iob_wdata_i (fe_iob_wdata_i),
      .fe_iob_wstrb_i (fe_iob_wstrb_i),
      .fe_iob_rvalid_o(fe_iob_rvalid_o),
      .fe_iob_rdata_o (fe_iob_rdata_o),
      .fe_iob_ready_o (fe_iob_ready_o),
      //back-end
      `include "iob_axi_m_m_portmap.vs"
      //general
      .clk_i(clk),
      .rst_i(arst),
      .cke_i(cke_i)                   
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
      .fe_iob_avalid_i(fe_iob_avalid_i),
      .fe_iob_addr_i  (fe_iob_addr_i[ADDR_W-1:$clog2(DATA_W/8)]),
      .fe_iob_wdata_i (fe_iob_wdata_i),
      .fe_iob_wstrb_i (fe_iob_wstrb_i),
      .fe_iob_rvalid_o(fe_iob_rvalid_o),
      .fe_iob_rdata_o (fe_iob_rdata_o),
      .fe_iob_ready_o (fe_iob_ready_o),
                        //back-end
      .be_iob_avalid_o(be_iob_avalid_o),
      .be_iob_addr_o  (be_iob_addr_o),
      .be_iob_wdata_o (be_iob_wdata_o),
      .be_iob_wstrb_o (be_iob_wstrb_o),
      .be_iob_rvalid_i(be_iob_rvalid_i),
      .be_iob_rdata_i (be_iob_rdata_i),
      .be_iob_ready_i (1'b1),
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
         be_iob_rvalid_i <= be_iob_avalid_o;
      end
   end

`endif



   
   // write through buffer memory
   iob_ram_2p #(
                .DATA_W(FIFO_DATA_W),
                .ADDR_W(FIFO_ADDR_W)
                ) iob_ram_2p0 (
          .clk_i(clk_i),

          .w_en_i  (mem_w_en),
          .w_addr_i(mem_w_addr),
          .w_data_i(mem_w_data),

          .r_en_i  (mem_r_en),
          .r_addr_i(mem_r_addr),
          .r_data_o(mem_r_data)
      );

  
endmodule

