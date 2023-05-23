`timescale 1ns / 1ps

`include "iob_cache.vh"
`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_read_channel #(
   parameter ADDR_W        = `IOB_CACHE_ADDR_W,
   parameter DATA_W        = `IOB_CACHE_DATA_W,
   parameter BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
   parameter BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
   parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W
) (
   input                                                             clk_i,
   input                                                             reset,
   input                                                             replace_valid,
   input      [ADDR_W-1:`IOB_CACHE_BE_NBYTES_W+`IOB_CACHE_LINE2BE_W] replace_addr,
   output reg                                                        replace,
   output reg                                                        read_valid,
   output reg [                            `IOB_CACHE_LINE2BE_W-1:0] read_addr,
   output     [                                       BE_DATA_W-1:0] read_rdata,

   // Native memory interface
   output     [BE_ADDR_W-1:0] be_addr,
   output reg                 be_valid,
   input                      be_ready,
   input      [BE_DATA_W-1:0] be_rdata
);

   generate
      if (`IOB_CACHE_LINE2BE_W > 0) begin: g_line2be_w
         reg [`IOB_CACHE_LINE2BE_W-1:0] word_counter;

         assign be_addr   = {BE_ADDR_W{1'b0}} + {replace_addr[ADDR_W-1 : `IOB_CACHE_BE_NBYTES_W+`IOB_CACHE_LINE2BE_W], word_counter, {`IOB_CACHE_BE_NBYTES_W{1'b0}}};
         assign read_rdata = be_rdata;

         localparam
           idle             = 2'd0,
           handshake        = 2'd1, // the process was divided in 2 handshake steps to cause a delay in the
         end_handshake = 2'd2;  // (always 1 or a delayed valid signal), otherwise it will fail

         always @(posedge clk_i) read_addr <= word_counter;

         reg [1:0] state;

         always @(posedge clk_i, posedge reset) begin
            if (reset) begin
               state <= idle;
            end else begin
               case (state)
                  idle: begin
                     if (replace_valid)  // main_process flag
                        state <= handshake;
                     else state <= idle;
                  end
                  handshake: begin
                     if (be_ready)
                        if (read_addr == {`IOB_CACHE_LINE2BE_W{1'b1}}) begin
                           state <= end_handshake;
                        end else begin
                           state <= handshake;
                        end
                     else begin
                        state <= handshake;
                     end
                  end
                  end_handshake: begin  // read-latency delay (last line word)
                     state <= idle;
                  end
                  default: ;
               endcase
            end
         end

         always @* begin
            be_valid     = 1'b0;
            replace      = 1'b1;
            word_counter = 0;
            read_valid   = 1'b0;

            case (state)
               idle: begin
                  replace = 1'b0;
               end
               handshake: begin
                  be_valid     = ~be_ready | ~(&read_addr);
                  word_counter = read_addr + be_ready;
                  read_valid   = be_ready;
               end
               default: ;
            endcase
         end
      end else begin: g_no_line2be_w
         assign be_addr    = {BE_ADDR_W{1'b0}} + {replace_addr, {`IOB_CACHE_BE_NBYTES_W{1'b0}}};
         assign read_rdata = be_rdata;

         localparam
           idle             = 2'd0,
           handshake        = 2'd1, // the process was divided in 2 handshake steps to cause a delay in the
         end_handshake = 2'd2;  // (always 1 or a delayed valid signal), otherwise it will fail

         reg [1:0] state;

         always @(posedge clk_i, posedge reset) begin
            if (reset) state <= idle;
            else begin
               case (state)
                  idle: begin
                     if (replace_valid) state <= handshake;
                     else state <= idle;
                  end
                  handshake: begin
                     if (be_ready) state <= end_handshake;
                     else state <= handshake;
                  end
                  end_handshake: begin  // read-latency delay (last line word)
                     state <= idle;
                  end
                  default: ;
               endcase
            end
         end

         always @* begin
            be_valid   = 1'b0;
            replace    = 1'b1;
            read_valid = 1'b0;

            case (state)
               idle: begin
                  replace = 1'b0;
               end
               handshake: begin
                  be_valid   = ~be_ready;
                  read_valid = be_ready;
               end
               default: ;
            endcase
         end
      end
   endgenerate

endmodule
