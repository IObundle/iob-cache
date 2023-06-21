`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"
`include "iob_cache_conf.vh"

// performance measuring, information about the current
// cache status, and other functions

module iob_cache_control #(
    parameter ADDR_W       = 32,
    parameter DATA_W       = 32
) (
    input                   clk_i,
    input                   arst_i,

   //read interface
    input                   req_i,
    input [ADDR_W-1:0]      addr_i,
    output reg [DATA_W-1:0] rdata_o,
    output reg              ack_o,

   //control signals
    input                   write_hit,
    input                   write_miss,
    input                   read_hit,
    input                   read_miss,
    output reg              invalidate
);

   //performance counters
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
        read_hit_cnt <= read_hit_cnt + read_hit;
        write_hit_cnt <= write_hit_cnt + write_hit;
        read_miss_cnt <= read_miss_cnt + read_miss;
        read_hit_cnt  <= read_hit_cnt - read_miss;
        write_miss_cnt <= write_miss_cnt + write_miss;
      end else begin
        read_hit_cnt   <= read_hit_cnt;
        read_miss_cnt  <= read_miss_cnt;
        write_hit_cnt  <= write_hit_cnt;
        write_miss_cnt <= write_miss_cnt;
      end
    end
  end

  always @(posedge clk_i, posedge arst_i) begin
     if (arst_i) begin
        rdata_o <= {DATA_W{1'b0}};
        invalidate <= 1'b0;
        reset_counters <= 1'b0;
        ack_o <= req_i;  // Sends acknowlege the next clock cycle after request (handshake)
     end else if (req_i) begin
        if (addr == `IOB_CACHE_RW_HIT_ADDR) rdata_o <= hit_cnt;
        else if (addr == `IOB_CACHE_RW_MISS_ADDR) rdata_o <= miss_cnt;
        else if (addr == `IOB_CACHE_READ_HIT_ADDR) rdata_o <= read_hit_cnt;
        else if (addr == `IOB_CACHE_READ_MISS_ADDR) rdata_o <= read_miss_cnt;
        else if (addr == `IOB_CACHE_WRITE_HIT_ADDR) rdata_o <= write_hit_cnt;
        else if (addr == `IOB_CACHE_WRITE_MISS_ADDR) rdata_o <= write_miss_cnt;
        else if (addr == `IOB_CACHE_RST_CNTRS_ADDR) reset_counters <= 1'b1;
        else if (addr == `IOB_CACHE_INVALIDATE_ADDR) invalidate <= 1'b1;
        else rdata_o <= `IOB_CACHE_VERSION;
     end
  end
endmodule
