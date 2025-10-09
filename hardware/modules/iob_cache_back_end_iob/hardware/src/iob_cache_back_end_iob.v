// SPDX-FileCopyrightText: 2024 IObundle
//
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps

`include "iob_cache_back_end_iob_conf.vh"

module iob_cache_back_end_iob #(
   `include "iob_cache_back_end_iob_params.vs"
) (
   `include "iob_cache_back_end_iob_io.vs"
);

   wire [BE_ADDR_W-1:0] be_addr_read, be_addr_write;
   wire be_valid_read, be_valid_write;
   wire be_ack;
   wire be_wack;
   wire be_wack_r;

   assign iob_addr_o  = (be_valid_read) ? be_addr_read : be_addr_write;
   assign iob_valid_o = be_valid_read | be_valid_write;
   assign be_ack      = iob_rvalid_i | be_wack_r;
   assign be_wack     = iob_ready_i & iob_valid_o & (|iob_wstrb_o);

   iob_reg_care #(
      .DATA_W (1),
      .RST_VAL(0)
   ) iob_reg_be_wack (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (1'b0),
      .en_i  (1'b1),
      .data_i(be_wack),
      .data_o(be_wack_r)
   );

   iob_cache_read_channel_iob #(
      .FE_ADDR_W    (FE_ADDR_W),
      .FE_DATA_W    (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W)
   ) read_fsm (
      .clk_i          (clk_i),
      .reset_i        (arst_i),
      .replace_valid_i(replace_valid_i),
      .replace_addr_i (replace_addr_i),
      .replace_o      (replace_o),
      .read_valid_o   (read_valid_o),
      .read_addr_o    (read_addr_o),
      .read_rdata_o   (read_rdata_o),
      .be_addr_o      (be_addr_read),
      .be_valid_o     (be_valid_read),
      .be_ack_i       (be_ack),
      .be_rdata_i     (iob_rdata_i)
   );

   iob_cache_write_channel_iob #(
      .ADDR_W       (FE_ADDR_W),
      .DATA_W       (FE_DATA_W),
      .BE_ADDR_W    (BE_ADDR_W),
      .BE_DATA_W    (BE_DATA_W),
      .WRITE_POL    (WRITE_POL),
      .WORD_OFFSET_W(WORD_OFFSET_W)
   ) write_fsm (
      .clk_i  (clk_i),
      .reset_i(arst_i),

      .valid_i(write_valid_i),
      .addr_i (write_addr_i),
      .wstrb_i(write_wstrb_i),
      .wdata_i(write_wdata_i),
      .ready_o(write_ready_o),

      .be_addr_o (be_addr_write),
      .be_valid_o(be_valid_write),
      .be_ack_i  (be_ack),
      .be_wdata_o(iob_wdata_o),
      .be_wstrb_o(iob_wstrb_o)
   );

endmodule
