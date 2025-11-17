// SPDX-FileCopyrightText: 2024 IObundle
//
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps

`include "iob_cache_control_conf.vh"
`include "iob_cache_iob_csrs_conf.vh"
`include "iob_cache_iob_csrs.vh"

// Module responsible for performance measuring, information about the current
// cache state, and other cache functions

module iob_cache_control #(
   `include "iob_cache_control_params.vs"
) (
   `include "iob_cache_control_io.vs"
);

   generate
      if (USE_CTRL_CNT) begin : g_ctrl_cnt
         reg [DATA_W-1:0] read_hit_cnt, read_miss_cnt, write_hit_cnt, write_miss_cnt;
         wire [DATA_W-1:0] hit_cnt, miss_cnt;
         reg reset_counters;

         assign hit_cnt  = read_hit_cnt + write_hit_cnt;
         assign miss_cnt = read_miss_cnt + write_miss_cnt;

         always @(posedge clk_i, posedge arst_i) begin
            if (arst_i) begin
               read_hit_cnt   <= {DATA_W{1'b0}};
               read_miss_cnt  <= {DATA_W{1'b0}};
               write_hit_cnt  <= {DATA_W{1'b0}};
               write_miss_cnt <= {DATA_W{1'b0}};
            end else begin
               if (reset_counters) begin
                  read_hit_cnt   <= {DATA_W{1'b0}};
                  read_miss_cnt  <= {DATA_W{1'b0}};
                  write_hit_cnt  <= {DATA_W{1'b0}};
                  write_miss_cnt <= {DATA_W{1'b0}};
               end else if (read_hit_i) begin
                  read_hit_cnt <= read_hit_cnt + 1'b1;
               end else if (write_hit_i) begin
                  write_hit_cnt <= write_hit_cnt + 1'b1;
               end else if (read_miss_i) begin
                  read_miss_cnt <= read_miss_cnt + 1'b1;
                  read_hit_cnt  <= read_hit_cnt - 1'b1;
               end else if (write_miss_i) begin
                  write_miss_cnt <= write_miss_cnt + 1'b1;
               end else begin
                  read_hit_cnt   <= read_hit_cnt;
                  read_miss_cnt  <= read_miss_cnt;
                  write_hit_cnt  <= write_hit_cnt;
                  write_miss_cnt <= write_miss_cnt;
               end
            end
         end

         always @(posedge clk_i) begin
            rdata_o <= {DATA_W{1'b0}};
            invalidate_o <= 1'b0;
            reset_counters <= 1'b0;
            ready_o <= valid_i;  // Sends acknowlege the next clock cycle after request (handshake)

            if (valid_i)
               if (addr_i == `IOB_CACHE_IOB_CSRS_RW_HIT_ADDR >> 2) rdata_o <= hit_cnt;
               else if (addr_i == `IOB_CACHE_IOB_CSRS_RW_MISS_ADDR >> 2) rdata_o <= miss_cnt;
               else if (addr_i == `IOB_CACHE_IOB_CSRS_READ_HIT_ADDR >> 2) rdata_o <= read_hit_cnt;
               else if (addr_i == `IOB_CACHE_IOB_CSRS_READ_MISS_ADDR >> 2) rdata_o <= read_miss_cnt;
               else if (addr_i == `IOB_CACHE_IOB_CSRS_WRITE_HIT_ADDR >> 2) rdata_o <= write_hit_cnt;
               else if (addr_i == `IOB_CACHE_IOB_CSRS_WRITE_MISS_ADDR >> 2) rdata_o <= write_miss_cnt;
               else if (addr_i == `IOB_CACHE_IOB_CSRS_RST_CNTRS_ADDR >> 2) reset_counters <= 1'b1;
         end
      end else begin : g_no_ctrl_cnt
         always @(posedge clk_i) begin
            rdata_o <= {DATA_W{1'b0}};
            invalidate_o <= 1'b0;
            ready_o <= valid_i;  // Sends acknowlege the next clock cycle after request (handshake)
            if (valid_i)
               if (addr_i == `IOB_CACHE_IOB_CSRS_INVALIDATE_ADDR >> 2) invalidate_o <= 1'b1;
               else if (addr_i == `IOB_CACHE_IOB_CSRS_WTB_EMPTY_ADDR >> 2) rdata_o <= wtbuf_empty_i;
               else if (addr_i == `IOB_CACHE_IOB_CSRS_WTB_FULL_ADDR >> 2) rdata_o <= wtbuf_full_i;
               else if (addr_i == `IOB_CACHE_IOB_CSRS_VERSION_ADDR >> 2)
                  rdata_o <= `IOB_CACHE_IOB_CSRS_VERSION;
         end
      end

   endgenerate

endmodule
