`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"
`include "iob_cache_conf.vh"

module iob_cache_read_channel #(
   parameter FE_ADDR_W     = `IOB_CACHE_ADDR_W,
   parameter FE_DATA_W     = `IOB_CACHE_DATA_W,
   parameter BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
   parameter BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
   parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
   //derived parameters
   parameter BE_NBYTES     = BE_DATA_W / 8,
   parameter BE_NBYTES_W   = $clog2(BE_NBYTES),
   parameter LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W)
) (
   input                                          clk_i,
   input                                          reset_i,
   input                                          replace_valid_i,
   input      [FE_ADDR_W-1:BE_NBYTES_W+LINE2BE_W] replace_addr_i,
   output reg                                     replace_o,
   output reg                                     read_valid_o,
   output reg [                    LINE2BE_W-1:0] read_addr_o,
   output     [                    BE_DATA_W-1:0] read_rdata_o,

   // Native memory interface
   output     [BE_ADDR_W-1:0] be_addr_o,
   output reg                 be_valid_o,
   input                      be_ack_i,
   input      [BE_DATA_W-1:0] be_rdata_i
);

   generate
      if (LINE2BE_W > 0) begin : g_line2be_w
         reg [LINE2BE_W-1:0] word_counter;

         assign be_addr_o   = {BE_ADDR_W{1'b0}} + {replace_addr_i[FE_ADDR_W-1 : BE_NBYTES_W+LINE2BE_W], word_counter, {BE_NBYTES_W{1'b0}}};
         assign read_rdata_o = be_rdata_i;

         localparam
           idle             = 2'd0,
           handshake        = 2'd1, // the process was divided in 2 handshake steps to cause a delay in the
         end_handshake = 2'd2;  // (always 1 or a delayed valid signal), otherwise it will fail

         always @(posedge clk_i) read_addr_o <= word_counter;

         reg [1:0] state;

         always @(posedge clk_i, posedge reset_i) begin
            if (reset_i) begin
               state <= idle;
            end else begin
               case (state)
                  idle: begin
                     if (replace_valid_i)  // main_process flag
                        state <= handshake;
                     else state <= idle;
                  end
                  handshake: begin
                     if (be_ack_i)
                        if (read_addr_o == {LINE2BE_W{1'b1}}) begin
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
            be_valid_o     = 1'b0;
            replace_o      = 1'b1;
            word_counter = 0;
            read_valid_o   = 1'b0;

            case (state)
               idle: begin
                  replace_o = 1'b0;
               end
               handshake: begin
                  be_valid_o     = ~be_ack_i | ~(&read_addr_o);
                  word_counter = read_addr_o + be_ack_i;
                  read_valid_o   = be_ack_i;
               end
               default: ;
            endcase
         end
      end else begin : g_no_line2be_w
         assign be_addr_o    = {BE_ADDR_W{1'b0}} + {replace_addr_i, {BE_NBYTES_W{1'b0}}};
         assign read_rdata_o = be_rdata_i;

         localparam
           idle             = 2'd0,
           handshake        = 2'd1, // the process was divided in 2 handshake steps to cause a delay in the
         end_handshake = 2'd2;  // (always 1 or a delayed valid signal), otherwise it will fail

         reg [1:0] state;

         always @(posedge clk_i, posedge reset_i) begin
            if (reset_i) state <= idle;
            else begin
               case (state)
                  idle: begin
                     if (replace_valid_i) state <= handshake;
                     else state <= idle;
                  end
                  handshake: begin
                     if (be_ack_i) state <= end_handshake;
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
            be_valid_o   = 1'b0;
            replace_o    = 1'b1;
            read_valid_o = 1'b0;

            case (state)
               idle: begin
                  replace_o = 1'b0;
               end
               handshake: begin
                  be_valid_o   = ~be_ack_i;
                  read_valid_o = be_ack_i;
               end
               default: ;
            endcase
         end
      end
   endgenerate

endmodule
