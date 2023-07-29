`timescale 1ns / 10ps
`include "iob_utils.vh"
`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_tb;

   localparam ADDR_W = `IOB_CACHE_ADDR_W;
   localparam DATA_W = `IOB_CACHE_DATA_W;
   localparam FE_ADDR_W = `IOB_CACHE_FE_ADDR_W;
   localparam FE_DATA_W = `IOB_CACHE_FE_DATA_W;
   localparam FE_NBYTES = `IOB_CACHE_FE_NBYTES;
   localparam BE_ADDR_W = `IOB_CACHE_BE_ADDR_W;
   localparam BE_DATA_W = `IOB_CACHE_BE_DATA_W;
   localparam BE_NBYTES = `IOB_CACHE_BE_NBYTES;
   localparam BE_RATIO_W = `IOB_CACHE_BE_RATIO_W;
   localparam NLINES_W = `IOB_CACHE_NLINES_W;
   localparam LINE_W = `IOB_CACHE_LINE_W;
   localparam NWAYS_W = `IOB_CACHE_NWAYS_W;
   localparam NWAYS = `IOB_CACHE_NWAYS;
   localparam NWORDS_W = `IOB_CACHE_NWORDS_W;
   localparam REPLACE_POL = `IOB_CACHE_REPLACE_POL;
   localparam TAG_W = `IOB_CACHE_TAG_W;
   localparam WRITE_POL = `IOB_CACHE_WRITE_POL;
   localparam NBYTES = `IOB_CACHE_NBYTES;
   localparam WTB_DEPTH_W = `IOB_CACHE_WTB_DEPTH_W;
   localparam WTB_DATA_W = `IOB_CACHE_DATA_W;
   localparam DMEM_DATA_W = `IOB_CACHE_DMEM_DATA_W;
   localparam DMEM_NBYTES = `IOB_CACHE_DMEM_NBYTES;
   localparam TAGMEM_DATA_W = `IOB_CACHE_TAGMEM_DATA_W;
   
   //global reset
   reg cke = 0;
   
   //clock period
   localparam CLK_PER = 10;  //ns

   //clock
   `IOB_CLOCK(clk, CLK_PER)

   //async reset
   reg arst;

   //control bus
`include "iob_m_tb_wire.vs"

   //frontend data bus
`include "fe_iob_m_tb_wire.vs"
   
   //backend data bus to memory
`include "be_iob_wire.vs"


   reg [`IOB_CACHE_DATA_W-1:0] data;

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

      //reset core
      `IOB_RESET(clk, arst, CLK_PER, CLK_PER, CLK_PER)

      for (i = 0; i < 10; i=i+1) begin
         iob_write(4*i, i, DATA_W);
      end
      for (i = 0; i < 10; i=i+1) begin
         iob_read(4*i, data, DATA_W);
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
   // Intantiate Cache
   //
   iob_cache_wt
     #(
 `include "iob_cache_inst_params.vs"
       ) 
   cache
     (
      //control
 `include "iob_s_s_portmap.vs"
      //front-end
 `include "fe_iob_s_s_portmap.vs"
      //back-end
 `include "fe_iob_s_s_portmap.vs"
      .clk_i(clk),
      .arst_i(arst),
      .cke_i(cke)
   );

   //
   // cache data memory
   //
   iob_ram_sp_be #(
      .DATA_W(BE_DATA_W),
      .ADDR_W(BE_ADDR_W)
   ) cache_data_mem (
      .clk_i (clk),
      .en_i  (be_iob_avalid),
      .addr_i(be_iob_addr),
      .d_i   (be_iob_wdata),
      .we_i  (be_iob_wstrb),
      .d_o   (be_iob_rdata)
   );

   assign be_iob_ready = 1;
   
   iob_reg #(
      .DATA_W(1)
   ) rvalid_reg (
      .clk_i (clk),
      .arst_i(arst),
      .cke_i  (cke),
      .d_i   (be_iob_avalid),
      .d_o   (be_iob_rvalid)
   );
   
  
   //
   // write through buffer memory
   //
   
   wire              wtb_mem_w_en;
   wire [FE_ADDR_W-1:0] wtb_mem_w_addr;
   wire [FE_DATA_W-1:0] wtb_mem_w_data;
   
   wire [FE_DATA_W-1:0] wtb_mem_r_data;
   wire [FE_DATA_W/8-1:0] wtb_mem_r_addr;
   wire                   wtb_mem_r_en;
  
   iob_ram_2p 
     #(
       .DATA_W(WTB_DATA_W),
       .ADDR_W(WTB_DEPTH_W)
       ) 
   wtb_mem
     (
      .clk_i(clk),
      
      .w_en_i  (wtb_mem_w_en),
      .w_addr_i(wtb_mem_w_addr),
      .w_data_i(wtb_mem_w_data),
      
      .r_en_i  (wtb_mem_r_en),
      .r_addr_i(wtb_mem_r_addr),
      .r_data_o(wtb_mem_r_data)
      );

   //
   // system memory
   //
   iob_ram_sp_be #(
      .DATA_W(BE_DATA_W),
      .ADDR_W(BE_ADDR_W)
   ) sys_mem (
      .clk_i (clk),
      .en_i  (be_iob_avalid),
      .addr_i(be_iob_addr),
      .d_i   (be_iob_wdata),
      .we_i  (be_iob_wstrb),
      .d_o   (be_iob_rdata)
   );
   
endmodule

