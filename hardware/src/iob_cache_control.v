`timescale 1ns / 1ps

`include "iob_cache.vh"

/*------------------*/
/* Cache Control    */
/*------------------*/
// Module responsible for performance measuring, information about the current cache state, and other cache functions

module iob_cache_control
  #(
    parameter DATA_W = 32,
    parameter USE_CTRL_CNT = 1
    )
   (
    input                      clk,
    input                      reset,
    input                      valid,
    input [`CTRL_ADDR_W-1:0]   addr,
    input                      wtbuf_full,
    input                      wtbuf_empty,
    input                      write_hit,
    input                      write_miss,
    input                      read_hit,
    input                      read_miss,
    output reg [DATA_W-1:0] rdata,
    output reg                 ready,
    output reg                 invalidate
    );

   generate
      if (USE_CTRL_CNT) begin
         reg [DATA_W-1:0]             read_hit_cnt, read_miss_cnt, write_hit_cnt, write_miss_cnt;
         wire [DATA_W-1:0]            hit_cnt, miss_cnt;
         reg                             reset_counters;

         assign hit_cnt  = read_hit_cnt  + write_hit_cnt;
         assign miss_cnt = read_miss_cnt + write_miss_cnt;

         always @(posedge clk, posedge reset) begin
            if (reset) begin
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
               end else if (read_hit) begin
                  read_hit_cnt <= read_hit_cnt + 1'b1;
               end else if (write_hit) begin
                  write_hit_cnt <= write_hit_cnt + 1'b1;
               end else if (read_miss) begin
                  read_miss_cnt <= read_miss_cnt + 1'b1;
                  read_hit_cnt  <= read_hit_cnt - 1'b1;
               end else if (write_miss) begin
                  write_miss_cnt <= write_miss_cnt + 1'b1;
               end else begin
                  read_hit_cnt   <= read_hit_cnt;
                  read_miss_cnt  <= read_miss_cnt;
                  write_hit_cnt  <= write_hit_cnt;
                  write_miss_cnt <= write_miss_cnt;
               end
            end
         end

         always @(posedge clk) begin
            rdata <= {DATA_W{1'b0}};
            invalidate <= 1'b0;
            reset_counters <= 1'b0;
            ready <= valid; // Sends acknowlege the next clock cycle after request (handshake)

            if (valid)
              if (addr == `ADDR_RW_HIT)
                rdata <= hit_cnt;
              else if (addr == `ADDR_RW_MISS)
                rdata <= miss_cnt;
              else if (addr == `ADDR_READ_HIT)
                rdata <= read_hit_cnt;
              else if (addr == `ADDR_READ_MISS)
                rdata <= read_miss_cnt;
              else if (addr == `ADDR_WRITE_HIT)
                rdata <= write_hit_cnt;
              else if (addr == `ADDR_WRITE_MISS)
                rdata <= write_miss_cnt;
              else if (addr == `ADDR_RST_CNTRS)   
                reset_counters <= 1'b1;
              else if (addr == `ADDR_INVALIDATE)
                invalidate <= 1'b1;
              else if (addr == `ADDR_WTB_EMPTY)
                rdata <= wtbuf_empty;
              else if (addr == `ADDR_WTB_FULL)
                rdata <= wtbuf_full;
              else if (addr == `ADDR_VERSION)
		rdata <= `VERSION;
         end
      end else begin
         always @(posedge clk) begin
            rdata <= {DATA_W{1'b0}};
            invalidate <= 1'b0;
            ready <= valid; // Sends acknowlege the next clock cycle after request (handshake)
            if (valid)
              if (addr == `ADDR_INVALIDATE)
                invalidate <= 1'b1;
              else if (addr == `ADDR_WTB_EMPTY)
                rdata <= wtbuf_empty;
              else if (addr == `ADDR_WTB_FULL)
                rdata <= wtbuf_full;
         end
      end
   endgenerate

endmodule
