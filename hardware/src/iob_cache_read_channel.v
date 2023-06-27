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
   input                                     clk_i,
   input                                     arst_i,

   //read request
   input                                     read_req_i,
   input [FE_ADDR_W-1:BE_NBYTES_W+LINE2BE_W] read_req_addr_i,

   //read response
   output reg                                read_valid_o,
   output reg [ LINE2BE_W-1:0]               read_addr_o,
   output reg                                read_busy_o,

   //back-end read interface
   output reg                                be_valid_o,
   output [BE_ADDR_W-1:0]                    be_addr_o,
   input                                     be_ready_i,
   input                                     be_rvalid_i,
   input [BE_DATA_W-1:0]                     be_rdata_i
);

   localparam
     idle             = 2'd0,
     handshake        = 2'd1, // the process was divided in 2 handshake steps to cause a delay in the
     end_handshake = 2'd2;  // (always 1 or a delayed valid signal), otherwise it will fail

   generate
      if (LINE2BE_W > 0) begin : g_line2be_w
         reg [LINE2BE_W-1:0] word_counter;

         assign be_addr_o   = {BE_ADDR_W{1'b0}} + {read_req_addr_i[FE_ADDR_W-1 : BE_NBYTES_W+LINE2BE_W], word_counter, {BE_NBYTES_W{1'b0}}};

         always @(posedge clk_i, posedge arst_i) begin
            if (arst_i) begin 
            read_addr_o <= 1'b0;
            end else begin
               read_addr_o <= word_counter;
            end
         end
         
         reg [1:0] state;

         always @(posedge clk_i, posedge arst_i) begin
            if (arst_i) begin
               state <= idle;
            end else begin
               case (state)
                  idle: begin
                     if (read_req_i && be_ready_i)  // main_process flag
                        state <= handshake;
                     else state <= idle;
                  end
                  handshake: begin
                     if (be_rvalid_i) begin
                        if (read_addr_o == {LINE2BE_W{1'b1}}) begin
                           state <= end_handshake;
                        end else begin
                           state <= handshake;
                        end
                     end else begin
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
            case (state)
               idle: begin
                  be_valid_o     = 1'b0;
                  word_counter = 0;
                  read_valid_o   = 1'b0;
                  read_busy_o  = 1'b0;
               end
               handshake: begin
                  be_valid_o     = ~be_rvalid_i | ~(&read_addr_o);
                  word_counter = read_addr_o + be_rvalid_i;
                  read_valid_o   = be_rvalid_i;
                  read_busy_o  = 1'b1;
               end
               default: begin
                  be_valid_o     = 1'b0;
                  word_counter = 0;
                  read_valid_o   = 1'b0;
                  read_busy_o  = 1'b1;
               end
            endcase
         end
      end else begin : g_no_line2be_w
         assign be_addr_o    = {BE_ADDR_W{1'b0}} + {read_req_addr_i, {BE_NBYTES_W{1'b0}}};

         reg [1:0] state;

         always @(posedge clk_i, posedge arst_i) begin
            if (arst_i) begin
               state <= idle;
            end else begin
               case (state)
                  idle: begin
                     if (read_req_i) state <= handshake;
                     else state <= idle;
                  end
                  handshake: begin
                     if (be_rvalid_i) state <= end_handshake;
                     else state <= handshake;
                  end
                  end_handshake: begin  // read-latency delay (last line word)
                     state <= idle;
                  end
                  default: ;
               endcase
            end
         end // always @ (posedge clk_i, posedge arst_i)

         always @* begin
            case (state)
               idle: begin
                  be_valid_o   = 1'b0;
                  read_valid_o = 1'b0;
                  read_busy_o = 1'b0;
               end
               handshake: begin
                  be_valid_o   = ~be_rvalid_i;
                  read_req_o = be_rvalid_i;
                  read_busy_o = 1'b1;
               end
               default: begin
                  be_valid_o   = 1'b0;
                  read_valid_o = 1'b0;
                  read_busy_o = 1'b1;
               end
            endcase
         end
      end
   endgenerate

endmodule
