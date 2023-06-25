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

   //control signals
    input                   write_hit_i,
    input                   write_miss_i,
    input                   read_hit_i,
    input                   read_miss_i,
    input                   reset_counters_i,
   //performance counters
    output reg [DATA_W-1:0] read_hit_cnt_o,
    output reg [DATA_W-1:0] read_miss_cnt_o, 
    output reg [DATA_W-1:0] write_hit_cnt_o, 
    output reg [DATA_W-1:0] write_miss_cnt_o
);


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
      end else begin
        read_hit_cnt <= read_hit_cnt + read_hit;
        write_hit_cnt <= write_hit_cnt + write_hit;
        read_miss_cnt <= read_miss_cnt + read_miss;
        read_hit_cnt  <= read_hit_cnt - read_miss;
        write_miss_cnt <= write_miss_cnt + write_miss;
      end
    end
  end

endmodule
