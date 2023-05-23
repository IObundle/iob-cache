`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache.vh"

module iob_cache_write_channel #(
   parameter ADDR_W        = `IOB_CACHE_ADDR_W,
   parameter DATA_W        = `IOB_CACHE_DATA_W,
   parameter BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
   parameter BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
   parameter WRITE_POL     = `IOB_CACHE_WRITE_THROUGH,
   parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W
) (
   input clk_i,
   input reset,

   input valid,
   input [ADDR_W-1 : `IOB_CACHE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] addr,
   input [`IOB_CACHE_NBYTES-1:0] wstrb,
   input [DATA_W + WRITE_POL*(DATA_W*(2**WORD_OFFSET_W)-DATA_W)-1:0] wdata, // try [DATA_W*((2**WORD_OFFSET_W)**WRITE_POL)-1:0] (f(x)=a*b^x)
   output reg ready,

   // Native Memory interface
   output     [          BE_ADDR_W -1:0] be_addr,
   output reg                            be_valid,
   input                                 be_ready,
   output     [           BE_DATA_W-1:0] be_wdata,
   output reg [`IOB_CACHE_BE_NBYTES-1:0] be_wstrb
);

   genvar i;

   generate
      if (WRITE_POL == `IOB_CACHE_WRITE_THROUGH) begin : g_write_through
         assign be_addr = {BE_ADDR_W{1'b0}} + {addr[ADDR_W-1 : `IOB_CACHE_BE_NBYTES_W], {`IOB_CACHE_BE_NBYTES_W{1'b0}}};

         localparam idle = 1'd0, write = 1'd1;

         reg [0:0] state;
         if (BE_DATA_W == DATA_W) begin : g_same_data_w
            assign be_wdata = wdata;

            always @* begin
               be_wstrb = 0;

               case (state)
                  write:   be_wstrb = wstrb;
                  default: ;
               endcase
            end
         end else begin : g_not_same_data_w
            wire [`IOB_CACHE_BE_NBYTES_W-`IOB_CACHE_NBYTES_W -1 :0] word_align = addr[`IOB_CACHE_NBYTES_W +: (`IOB_CACHE_BE_NBYTES_W - `IOB_CACHE_NBYTES_W)];

            for (i = 0; i < BE_DATA_W / DATA_W; i = i + 1) begin : g_wdata_block
               assign be_wdata[(i+1)*DATA_W-1:i*DATA_W] = wdata;
            end

            always @* begin
               be_wstrb = 0;

               case (state)
                  write:   be_wstrb = wstrb << word_align * `IOB_CACHE_NBYTES;
                  default: ;
               endcase
            end
         end

         always @(posedge clk_i, posedge reset) begin
            if (reset) state <= idle;
            else
               case (state)
                  idle: begin
                     if (valid) state <= write;
                     else state <= idle;
                  end
                  default: begin  // write
                     if (be_ready & ~valid) state <= idle;
                     else if (be_ready & valid)  // still has data to write
                        state <= write;
                     else state <= write;
                  end
               endcase
         end

         always @* begin
            ready    = 1'b0;
            be_valid = 1'b0;

            case (state)
               idle: ready = 1'b1;
               default: begin  // write
                  be_valid = ~be_ready;
                  ready    = be_ready;
               end
            endcase
         end
      end else begin : g_write_back
         // if (WRITE_POL == WRITE_BACK)
         if (`IOB_CACHE_LINE2BE_W > 0) begin : g_line2be_w
            reg [`IOB_CACHE_LINE2BE_W-1:0] word_counter, word_counter_reg;
            always @(posedge clk_i) word_counter_reg <= word_counter;

            // memory address
            assign be_addr  = {BE_ADDR_W{1'b0}} + {addr[ADDR_W-1: `IOB_CACHE_BE_NBYTES_W + `IOB_CACHE_LINE2BE_W], word_counter, {`IOB_CACHE_BE_NBYTES_W{1'b0}}};

            // memory write-data
            assign be_wdata = wdata >> (BE_DATA_W * word_counter);

            localparam idle = 1'd0, write = 1'd1;

            reg [0:0] state;

            always @(posedge clk_i, posedge reset) begin
               if (reset) state <= idle;
               else
                  case (state)
                     idle: begin
                        if (valid) state <= write;
                        else state <= idle;
                     end
                     default: begin  // write
                        if (be_ready & (&word_counter_reg)) state <= idle;
                        else state <= write;
                     end
                  endcase
            end

            always @* begin
               ready        = 1'b0;
               be_valid     = 1'b0;
               be_wstrb     = 0;
               word_counter = 0;

               case (state)
                  idle: begin
                     ready = ~valid;
                     if (valid) be_wstrb = {`IOB_CACHE_BE_NBYTES{1'b1}};
                     else be_wstrb = 0;
                  end
                  default: begin  // write
                     ready        = be_ready & (&word_counter);  // last word transfered
                     be_valid     = ~(be_ready & (&word_counter));
                     be_wstrb     = {`IOB_CACHE_BE_NBYTES{1'b1}};
                     word_counter = word_counter_reg + be_ready;
                  end
               endcase
            end
         end else begin : g_no_line2be_w
            // memory address
            assign be_addr  = {BE_ADDR_W{1'b0}} + {addr[ADDR_W-1: `IOB_CACHE_BE_NBYTES_W], {`IOB_CACHE_BE_NBYTES_W{1'b0}}};

            // memory write-data
            assign be_wdata = wdata;

            localparam idle = 1'd0, write = 1'd1;

            reg [0:0] state;

            always @(posedge clk_i, posedge reset) begin
               if (reset) state <= idle;
               else
                  case (state)
                     idle: begin
                        if (valid) state <= write;
                        else state <= idle;
                     end
                     default: begin  // write
                        if (be_ready) state <= idle;
                        else state <= write;
                     end
                  endcase
            end

            always @* begin
               ready    = 1'b0;
               be_valid = 1'b0;
               be_wstrb = 0;

               case (state)
                  idle: begin
                     ready = ~valid;
                     if (valid) be_wstrb = {`IOB_CACHE_BE_NBYTES{1'b1}};
                     else be_wstrb = 0;
                  end
                  default: begin  // write
                     ready    = be_ready;
                     be_valid = ~be_ready;
                     be_wstrb = {`IOB_CACHE_BE_NBYTES{1'b1}};
                  end
               endcase
            end
         end
      end
   endgenerate

endmodule
