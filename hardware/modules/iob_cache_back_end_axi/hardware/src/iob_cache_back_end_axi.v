// SPDX-FileCopyrightText: 2024 IObundle
//
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps

`include "iob_cache_back_end_axi_conf.vh"

module iob_cache_back_end_axi #(
   `include "iob_cache_back_end_axi_params.vs"
) (
   `include "iob_cache_back_end_axi_io.vs"
);

   iob_cache_read_channel_axi #(
      .ADDR_W       (FE_ADDR_W),
      .DATA_W       (FE_DATA_W),
      .BE_ADDR_W    (AXI_ADDR_W),
      .BE_DATA_W    (AXI_DATA_W),
      .WORD_OFFSET_W(WORD_OFFSET_W),
      .AXI_ADDR_W   (AXI_ADDR_W),
      .AXI_DATA_W   (AXI_DATA_W),
      .AXI_ID_W     (AXI_ID_W),
      .AXI_LEN_W    (AXI_LEN_W),
      .AXI_ID       (AXI_ID)
   ) read_fsm (
      .replace_valid_i(replace_valid_i),
      .replace_addr_i (replace_addr_i),
      .replace_o      (replace_o),
      .read_valid_o   (read_valid_o),
      .read_addr_o    (read_addr_o),
      .read_rdata_o   (read_rdata_o),

      .axi_araddr_o (axi_araddr_o),
      .axi_arprot_o  (),
      .axi_arvalid_o(axi_arvalid_o),
      .axi_arready_i(axi_arready_i),
      .axi_rdata_i  (axi_rdata_i),
      .axi_rresp_i  (axi_rresp_i),
      .axi_rvalid_i (axi_rvalid_i),
      .axi_rready_o (axi_rready_o),
      .axi_arid_o   (axi_arid_o),
      .axi_arlen_o  (axi_arlen_o),
      .axi_arsize_o (axi_arsize_o),
      .axi_arburst_o(axi_arburst_o),
      .axi_arlock_o (axi_arlock_o),
      .axi_arcache_o(axi_arcache_o),
      .axi_arqos_o  (axi_arqos_o),
      .axi_rid_i    (axi_rid_i),
      .axi_rlast_i  (axi_rlast_i),

      .clk_i  (clk_i),
      .reset_i(arst_i)
   );

   iob_cache_write_channel_axi #(
      .ADDR_W       (FE_ADDR_W),
      .DATA_W       (FE_DATA_W),
      .BE_ADDR_W    (AXI_ADDR_W),
      .BE_DATA_W    (AXI_DATA_W),
      .WRITE_POL    (WRITE_POL),
      .WORD_OFFSET_W(WORD_OFFSET_W),
      .AXI_ADDR_W   (AXI_ADDR_W),
      .AXI_DATA_W   (AXI_DATA_W),
      .AXI_ID_W     (AXI_ID_W),
      .AXI_LEN_W    (AXI_LEN_W),
      .AXI_ID       (AXI_ID)
   ) write_fsm (
      .valid_i(write_valid_i),
      .addr_i (write_addr_i),
      .wstrb_i(write_wstrb_i),
      .wdata_i(write_wdata_i),
      .ready_o(write_ready_o),

      .axi_awaddr_o (axi_awaddr_o),
      .axi_awprot_o (),
      .axi_awvalid_o(axi_awvalid_o),
      .axi_awready_i(axi_awready_i),
      .axi_wdata_o  (axi_wdata_o),
      .axi_wstrb_o  (axi_wstrb_o),
      .axi_wvalid_o (axi_wvalid_o),
      .axi_wready_i (axi_wready_i),
      .axi_bresp_i  (axi_bresp_i),
      .axi_bvalid_i (axi_bvalid_i),
      .axi_bready_o (axi_bready_o),
      .axi_awid_o   (axi_awid_o),
      .axi_awlen_o  (axi_awlen_o),
      .axi_awsize_o (axi_awsize_o),
      .axi_awburst_o(axi_awburst_o),
      .axi_awlock_o (axi_awlock_o),
      .axi_awcache_o(axi_awcache_o),
      .axi_awqos_o  (axi_awqos_o),
      .axi_wlast_o  (axi_wlast_o),
      .axi_bid_i    (axi_bid_i),

      .clk_i  (clk_i),
      .reset_i(arst_i)
   );

endmodule
