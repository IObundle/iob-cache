`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"
`include "iob_cache_conf.vh"

// performance measuring, information about the current
// cache status, and other functions

module iob_cache_monitor #(
    parameter ADDR_W       = 32,
    parameter DATA_W       = 32
) (
    input                   clk_i,
    input                   arst_i,
    input                   cke_i,

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
      read_hit_cnt_o   <= {DATA_W{1'b0}};
      read_miss_cnt_o  <= {DATA_W{1'b0}};
      write_hit_cnt_o  <= {DATA_W{1'b0}};
      write_miss_cnt_o <= {DATA_W{1'b0}};
    end else if (cke_i) begin
      if (reset_counters_i) begin
        read_hit_cnt_o   <= {DATA_W{1'b0}};
        read_miss_cnt_o  <= {DATA_W{1'b0}};
        write_hit_cnt_o  <= {DATA_W{1'b0}};
        write_miss_cnt_o <= {DATA_W{1'b0}};
      end else begin
        read_hit_cnt_o <= read_hit_cnt_o + read_hit_i;
        write_hit_cnt_o <= write_hit_cnt_o + write_hit_i;
        read_miss_cnt_o <= read_miss_cnt_o + read_miss_i;
        read_hit_cnt_o  <= read_hit_cnt_o - read_miss_i;
        write_miss_cnt_o <= write_miss_cnt_o + write_miss_i;
      end
    end
  end

endmodule
