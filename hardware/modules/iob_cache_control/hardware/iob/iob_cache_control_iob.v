// SPDX-FileCopyrightText: 2024 IObundle
//
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps

`include "iob_cache_control_conf.vh"
`include "iob_cache_iob_csrs_conf.vh"

// Module responsible for performance measuring, information about the current
// cache state, and other cache functions

module iob_cache_control #(
   `include "iob_cache_control_params.vs"
) (
   `include "iob_cache_control_io.vs"
);

   localparam WSTRB_W = DATA_W / 8;
   localparam BYTE_SHIFT = $clog2(WSTRB_W);

   wire [`IOB_CACHE_IOB_CSRS_ADDR_W-1:0] addr_int;
   wire [       ($clog2(WSTRB_W)+1)-1:0] byte_offset;
   // TODO: add iob_prio_enc subblock
   iob_prio_enc #(
      .W   (WSTRB_W),
      .MODE("LOW")
   ) prio_encoder0 (
      .unencoded_i(wstrb_i),
      .encoded_o  (byte_offset)
   );

   // ignore address LSBs
   assign addr_int = {addr_i[`IOB_CACHE_IOB_CSRS_ADDR_W-1:BYTE_SHIFT], {BYTE_SHIFT{1'b0}}} + byte_offset;

   generate
      if (USE_CTRL_CNT) begin : g_ctrl_cnt
         reg [DATA_W-1:0] read_hit_cnt, read_miss_cnt, write_hit_cnt, write_miss_cnt;
         reg [DATA_W-1:0] hit_cnt, miss_cnt;
         reg reset_counters;

         always @(posedge clk_i, posedge arst_i) begin
            if (arst_i) begin
               read_hit_cnt   <= {DATA_W{1'b0}};
               read_miss_cnt  <= {DATA_W{1'b0}};
               write_hit_cnt  <= {DATA_W{1'b0}};
               write_miss_cnt <= {DATA_W{1'b0}};
               hit_cnt        <= {DATA_W{1'b0}};
               miss_cnt       <= {DATA_W{1'b0}};
            end else begin
               if (reset_counters) begin
                  read_hit_cnt   <= {DATA_W{1'b0}};
                  read_miss_cnt  <= {DATA_W{1'b0}};
                  write_hit_cnt  <= {DATA_W{1'b0}};
                  write_miss_cnt <= {DATA_W{1'b0}};
                  hit_cnt        <= {DATA_W{1'b0}};
                  miss_cnt       <= {DATA_W{1'b0}};
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
                  hit_cnt        <= read_hit_cnt + write_hit_cnt;
                  miss_cnt       <= read_miss_cnt + write_miss_cnt;
               end
            end
         end

         always @(posedge clk_i) begin
            rdata_o <= {DATA_W{1'b0}};
            invalidate_o <= 1'b0;
            reset_counters <= 1'b0;
            ready_o <= valid_i;  // Sends acknowledge the next clock cycle after request (handshake)

            if (valid_i) begin
               if (wstrb_i == 0) begin  // read operation
                  if (addr_i == `IOB_CACHE_IOB_CSRS_RW_HIT_ADDR) rdata_o <= hit_cnt;
                  else if (addr_i == `IOB_CACHE_IOB_CSRS_RW_MISS_ADDR) rdata_o <= miss_cnt;
                  else if (addr_i == `IOB_CACHE_IOB_CSRS_READ_HIT_ADDR) rdata_o <= read_hit_cnt;
                  else if (addr_i == `IOB_CACHE_IOB_CSRS_READ_MISS_ADDR) rdata_o <= read_miss_cnt;
                  else if (addr_i == `IOB_CACHE_IOB_CSRS_WRITE_HIT_ADDR) rdata_o <= write_hit_cnt;
                  else if (addr_i == `IOB_CACHE_IOB_CSRS_WRITE_MISS_ADDR) rdata_o <= write_miss_cnt;
               end else begin  // write operation
                  if (addr_int == `IOB_CACHE_IOB_CSRS_RST_CNTRS_ADDR) reset_counters <= 1'b1;
                  else if (addr_int == `IOB_CACHE_IOB_CSRS_INVALIDATE_ADDR) invalidate_o <= 1'b1;
               end
            end
         end
      end else begin : g_no_ctrl_cnt
         always @(posedge clk_i) begin
            rdata_o <= {DATA_W{1'b0}};
            invalidate_o <= 1'b0;
            ready_o <= valid_i;  // Sends acknowledge the next clock cycle after request (handshake)
            if (valid_i) begin
               if (wstrb_i == 0) begin  // read operation
                  if (addr_i == `IOB_CACHE_IOB_CSRS_WTB_EMPTY_ADDR) rdata_o <= wtbuf_empty_i;
                  else if (addr_i == `IOB_CACHE_IOB_CSRS_WTB_FULL_ADDR) rdata_o <= wtbuf_full_i;
                  else if (addr_i == `IOB_CACHE_IOB_CSRS_VERSION_ADDR)
                     rdata_o <= `IOB_CACHE_IOB_CSRS_VERSION;
               end else begin  // write operation
                  if (addr_int == `IOB_CACHE_IOB_CSRS_INVALIDATE_ADDR) invalidate_o <= 1'b1;
               end
            end
         end
      end

   endgenerate

endmodule
