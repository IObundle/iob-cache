`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"
`include "iob_cache_conf.vh"

module iob_cache_write_channel #(
   parameter ADDR_W        = `IOB_CACHE_ADDR_W,
   parameter DATA_W        = `IOB_CACHE_DATA_W,
   parameter FE_ADDR_W     = `IOB_CACHE_FE_ADDR_W,
   parameter FE_DATA_W     = `IOB_CACHE_FE_DATA_W,
   parameter BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
   parameter BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
   parameter WRITE_POL     = `IOB_CACHE_WRITE_THROUGH,
   parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
   //derived parameters
   parameter FE_NBYTES     = FE_DATA_W / 8,
   parameter FE_NBYTES_W   = $clog2(FE_NBYTES),
   parameter BE_NBYTES     = BE_DATA_W / 8,
   parameter BE_NBYTES_W   = $clog2(BE_NBYTES),
   parameter LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W)
) (
   input clk_i,
   input reset_i,

   input valid_i,
   input [ADDR_W-1 : FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] addr_i,
   input [FE_NBYTES-1:0] wstrb_i,
   input [DATA_W + WRITE_POL*(DATA_W*(2**WORD_OFFSET_W)-DATA_W)-1:0] wdata_i, // try [DATA_W*((2**WORD_OFFSET_W)**WRITE_POL)-1:0] (f(x)=a*b^x)
   output reg ready_o,

   // Native Memory interface
   output     [BE_ADDR_W -1:0] be_addr_o,
   output reg                  be_valid_o,
   input                       be_ack_i,
   output     [ BE_DATA_W-1:0] be_wdata_o,
   output reg [ BE_NBYTES-1:0] be_wstrb_o
);

   genvar i;

   generate
      if (WRITE_POL == `IOB_CACHE_WRITE_THROUGH) begin : g_write_through
         assign be_addr_o = {BE_ADDR_W{1'b0}} + {addr_i[ADDR_W-1 : BE_NBYTES_W], {BE_NBYTES_W{1'b0}}};

         localparam idle = 1'd0, write = 1'd1;

         reg [0:0] state;
         if (BE_DATA_W == DATA_W) begin : g_same_data_w
            assign be_wdata_o = wdata_i;

            always @* begin
               be_wstrb_o = 0;

               case (state)
                  write:   be_wstrb_o = wstrb_i;
                  default: ;
               endcase
            end
         end else begin : g_not_same_data_w
            wire [BE_NBYTES_W-FE_NBYTES_W -1 :0] word_align = addr_i[FE_NBYTES_W +: (BE_NBYTES_W - FE_NBYTES_W)];

            for (i = 0; i < BE_DATA_W / DATA_W; i = i + 1) begin : g_wdata_block
               assign be_wdata_o[(i+1)*DATA_W-1:i*DATA_W] = wdata_i;
            end

            always @* begin
               be_wstrb_o = 0;

               case (state)
                  write:   be_wstrb_o = wstrb_i << word_align * FE_NBYTES;
                  default: ;
               endcase
            end
         end

         always @(posedge clk_i, posedge reset_i) begin
            if (reset_i) state <= idle;
            else
               case (state)
                  idle: begin
                     if (valid_i) state <= write;
                     else state <= idle;
                  end
                  default: begin  // write
                     if (be_ack_i & ~valid_i) state <= idle;
                     else if (be_ack_i & valid_i)  // still has data to write
                        state <= write;
                     else state <= write;
                  end
               endcase
         end

         always @* begin
            ready_o    = 1'b0;
            be_valid_o = 1'b0;

            case (state)
               idle: ready_o = 1'b1;
               default: begin  // write
                  be_valid_o = ~be_ack_i;
                  ready_o    = be_ack_i;
               end
            endcase
         end
      end else begin : g_write_back
         // if (WRITE_POL == WRITE_BACK)
         if (LINE2BE_W > 0) begin : g_line2be_w
            reg [LINE2BE_W-1:0] word_counter, word_counter_reg;
            always @(posedge clk_i) word_counter_reg <= word_counter;

            // memory address
            assign be_addr_o  = {BE_ADDR_W{1'b0}} + {addr_i[ADDR_W-1: BE_NBYTES_W + LINE2BE_W], word_counter, {BE_NBYTES_W{1'b0}}};

            // memory write-data
            assign be_wdata_o = wdata_i >> (BE_DATA_W * word_counter);

            localparam idle = 1'd0, write = 1'd1;

            reg [0:0] state;

            always @(posedge clk_i, posedge reset_i) begin
               if (reset_i) state <= idle;
               else
                  case (state)
                     idle: begin
                        if (valid_i) state <= write;
                        else state <= idle;
                     end
                     default: begin  // write
                        if (be_ack_i & (&word_counter_reg)) state <= idle;
                        else state <= write;
                     end
                  endcase
            end

            always @* begin
               ready_o        = 1'b0;
               be_valid_o     = 1'b0;
               be_wstrb_o     = 0;
               word_counter = 0;

               case (state)
                  idle: begin
                     ready_o = ~valid_i;
                     if (valid_i) be_wstrb_o = {BE_NBYTES{1'b1}};
                     else be_wstrb_o = 0;
                  end
                  default: begin  // write
                     ready_o        = be_ack_i & (&word_counter);  // last word transfered
                     be_valid_o     = ~(be_ack_i & (&word_counter));
                     be_wstrb_o     = {BE_NBYTES{1'b1}};
                     word_counter = word_counter_reg + be_ack_i;
                  end
               endcase
            end
         end else begin : g_no_line2be_w
            // memory address
            assign be_addr_o  = {BE_ADDR_W{1'b0}} + {addr_i[ADDR_W-1:BE_NBYTES_W], {BE_NBYTES_W{1'b0}}};

            // memory write-data
            assign be_wdata_o = wdata_i;

            localparam idle = 1'd0, write = 1'd1;

            reg [0:0] state;

            always @(posedge clk_i, posedge reset_i) begin
               if (reset_i) state <= idle;
               else
                  case (state)
                     idle: begin
                        if (valid_i) state <= write;
                        else state <= idle;
                     end
                     default: begin  // write
                        if (be_ack_i) state <= idle;
                        else state <= write;
                     end
                  endcase
            end

            always @* begin
               ready_o    = 1'b0;
               be_valid_o = 1'b0;
               be_wstrb_o = 0;

               case (state)
                  idle: begin
                     ready_o = ~valid_i;
                     if (valid_i) be_wstrb_o = {BE_NBYTES{1'b1}};
                     else be_wstrb_o = 0;
                  end
                  default: begin  // write
                     ready_o    = be_ack_i;
                     be_valid_o = ~be_ack_i;
                     be_wstrb_o = {BE_NBYTES{1'b1}};
                  end
               endcase
            end
         end
      end
   endgenerate

endmodule
