`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"

module iob_cache_front_end #(
   parameter ADDR_W = 32,
   parameter DATA_W = 32,

   // Derived parameters DO NOT CHANGE
   parameter USE_CTRL     = 0,
   parameter USE_CTRL_CNT = 0
) (
   // General ports
   input                                clk_i,
   input                                cke_i,
   input                                arst_i,
   // IOb-bus front-end
   input                                avalid,
   input [USE_CTRL + ADDR_W -1:0]       addr,
   input [ DATA_W-1:0]                  wdata,
   input [ DATA_W/8-1:0]                wstrb,
   output [ DATA_W-1:0]                 rdata,
   output                               rvalid,
   output                               ready,

   // internal input signals
   output                               data_req,
   output [ADDR_W-1:0]                  data_addr,
   input [DATA_W-1:0]                   data_rdata,
   input                                data_ack,

   // stored input signals
   output reg                           data_req_reg,
   output reg [ADDR_W-1:0]              data_addr_reg,
   output reg [DATA_W-1:0]              data_wdata_reg,
   output reg [DATA_W/8-1:0]            data_wstrb_reg,

   // cache-control
   output                               ctrl_req,
   output [`IOB_CACHE_SWREG_ADDR_W-1:0] ctrl_addr,
   input [ USE_CTRL*(DATA_W-1):0]       ctrl_rdata,
   input                                ctrl_ack
);

   wire ack;
   wire avalid_int;
   wire we_r;

   // select cache memory ir controller
   generate
      if (USE_CTRL) begin : g_ctrl
         // Front-end output signals
         assign ack          = ctrl_ack | data_ack;
         assign rdata        = (ctrl_ack) ? ctrl_rdata : data_rdata;

         assign avalid_int = ~addr[USE_CTRL+ADDR_W-1] & avalid;

         assign ctrl_req     = addr[USE_CTRL+ADDR_W-1] & avalid;
         assign ctrl_addr    = addr[`IOB_CACHE_SWREG_ADDR_W-1:0];

      end else begin : g_no_ctrl
         // Front-end output signals
         assign ack        = data_ack;
         assign rdata      = data_rdata;
         assign avalid_int = avalid;
         assign ctrl_req   = 1'bx;
         assign ctrl_addr  = `IOB_CACHE_SWREG_ADDR_W'dx;
      end
   endgenerate

   // data output ports
   assign data_addr = addr[ADDR_W-1 : 0];
   assign data_req  = avalid_int | data_req_reg;

   assign rvalid = we_r ? 1'b0 : ack;
   assign ready  = data_req_reg ~^ ack;

   // Register every input
   iob_reg_re #(
      .DATA_W (1),
      .RST_VAL(0)
   ) iob_reg_avalid (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (avalid_int|ack),
      .data_i(avalid_int),
      .data_o(data_req_reg)
   );
   iob_reg_re #(
      .DATA_W (ADDR_W),
      .RST_VAL(0)
   ) iob_reg_addr (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (avalid_int),
      .data_i(addr[ADDR_W-1:0]),
      .data_o(data_addr_reg)
   );
   iob_reg_re #(
      .DATA_W (DATA_W),
      .RST_VAL(0)
   ) iob_reg_wdata (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (avalid_int),
      .data_i(wdata),
      .data_o(data_wdata_reg)
   );
   iob_reg_re #(
      .DATA_W (DATA_W/8),
      .RST_VAL(0)
   ) iob_reg_wstrb (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (avalid_int),
      .data_i(wstrb),
      .data_o(data_wstrb_reg)
   );
   iob_reg_re #(
      .DATA_W (1),
      .RST_VAL(0)
   ) iob_reg_we (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (avalid_int),
      .data_i(|wstrb),
      .data_o(we_r)
   );

endmodule
