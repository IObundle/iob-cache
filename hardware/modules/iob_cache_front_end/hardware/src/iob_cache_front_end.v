// SPDX-FileCopyrightText: 2024 IObundle
//
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps

`include "iob_cache_front_end_conf.vh"
`include "iob_cache_csrs_conf.vh"

module iob_cache_front_end #(
   `include "iob_cache_front_end_params.vs"
) (
   `include "iob_cache_front_end_io.vs"
);

   wire ack;
   wire valid_int;
   wire we_r;

   // select cache memory ir controller
   generate
      if (USE_CTRL) begin : g_ctrl
         // Front-end output signals
         assign ack         = ctrl_ack_i | data_ack_i;
         assign iob_rdata_o = (ctrl_ack_i) ? ctrl_rdata_i : data_rdata_i;

         assign valid_int   = ~iob_addr_i[ADDR_W-1] & iob_valid_i;

         assign ctrl_req_o  = iob_addr_i[ADDR_W-1] & iob_valid_i;
         assign ctrl_addr_o = iob_addr_i[`IOB_CACHE_CSRS_ADDR_W-1:0];

      end else begin : g_no_ctrl
         // Front-end output signals
         assign ack         = data_ack_i;
         assign iob_rdata_o = data_rdata_i;
         assign valid_int   = iob_valid_i;
         assign ctrl_req_o  = 1'b0;
         assign ctrl_addr_o = `IOB_CACHE_CSRS_ADDR_W'dx;
      end
   endgenerate

   // data output ports
   assign data_addr_o  = iob_addr_i[ADDR_W-1 : 0];
   assign data_req_o   = valid_int | data_req_reg_o;

   assign iob_rvalid_o = we_r ? 1'b0 : ack;
   assign iob_ready_o  = data_req_reg_o ~^ ack;

   // Register every input
   iob_reg_care #(
      .DATA_W (1),
      .RST_VAL(0)
   ) iob_reg_valid (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (valid_int | ack),
      .data_i(valid_int),
      .data_o(data_req_reg_o)
   );
   iob_reg_care #(
      .DATA_W (ADDR_W - USE_CTRL),
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
   iob_reg_care #(
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
   iob_reg_care #(
      .DATA_W (DATA_W / 8),
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
   iob_reg_care #(
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
