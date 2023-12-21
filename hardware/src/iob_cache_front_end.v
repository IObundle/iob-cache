`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"
`include "iob_cache_conf.vh"

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
`include "iob_s_port.vs"

   // internal input signals
   output                               data_req_o,
   output [ADDR_W-USE_CTRL-1:0]        data_addr_o,
   input [DATA_W-1:0]                   data_rdata_i,
   input                                data_ack_i,

   // output registered input signals
   output reg                           data_req_reg_o,
   output reg [ADDR_W-USE_CTRL-1:0]     data_addr_reg_o,
   output reg [DATA_W-1:0]              data_wdata_reg_o,
   output reg [DATA_W/8-1:0]            data_wstrb_reg_o,

   // cache-control
   output                               ctrl_req_o,
   output [`IOB_CACHE_SWREG_ADDR_W-1:0] ctrl_addr_o,
   input [ USE_CTRL*(DATA_W-1):0]       ctrl_rdata_i,
   input                                ctrl_ack_i
);

   wire ack;
   wire valid_int;
   wire we_r;

   // select cache memory ir controller
   generate
      if (USE_CTRL) begin : g_ctrl
         // Front-end output signals
         assign ack          = ctrl_ack_i | data_ack_i;
         assign iob_rdata_o        = (ctrl_ack_i) ? ctrl_rdata_i : data_rdata_i;

         assign valid_int = ~iob_addr_i[ADDR_W-1] & iob_valid_i;

         assign ctrl_req_o     = iob_addr_i[ADDR_W-1] & iob_valid_i;
         assign ctrl_addr_o    = iob_addr_i[`IOB_CACHE_SWREG_ADDR_W-1:0];

      end else begin : g_no_ctrl
         // Front-end output signals
         assign ack        = data_ack_i;
         assign iob_rdata_o      = data_rdata_i;
         assign valid_int = iob_valid_i;
         assign ctrl_req_o   = 1'bx;
         assign ctrl_addr_o  = `IOB_CACHE_SWREG_ADDR_W'dx;
      end
   endgenerate

   // data output ports
   assign data_addr_o = iob_addr_i[ADDR_W-1 : 0];
   assign data_req_o  = valid_int | data_req_reg_o;

   assign iob_rvalid_o = we_r ? 1'b0 : ack;
   assign iob_ready_o  = data_req_reg_o ~^ ack;

   // Register every input
   iob_reg_re #(
      .DATA_W (1),
      .RST_VAL(0)
   ) iob_reg_valid (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (valid_int|ack),
      .data_i(valid_int),
      .data_o(data_req_reg_o)
   );
   iob_reg_re #(
      .DATA_W (ADDR_W-USE_CTRL),
      .RST_VAL(0)
   ) iob_reg_addr (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (valid_int),
      .data_i(iob_addr_i[ADDR_W-USE_CTRL-1:0]),
      .data_o(data_addr_reg_o)
   );
   iob_reg_re #(
      .DATA_W (DATA_W),
      .RST_VAL(0)
   ) iob_reg_wdata (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (valid_int),
      .data_i(iob_wdata_i),
      .data_o(data_wdata_reg_o)
   );
   iob_reg_re #(
      .DATA_W (DATA_W/8),
      .RST_VAL(0)
   ) iob_reg_wstrb (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (valid_int),
      .data_i(iob_wstrb_i),
      .data_o(data_wstrb_reg_o)
   );
   iob_reg_re #(
      .DATA_W (1),
      .RST_VAL(0)
   ) iob_reg_we (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (valid_int),
      .data_i(|iob_wstrb_i),
      .data_o(we_r)
   );

endmodule
