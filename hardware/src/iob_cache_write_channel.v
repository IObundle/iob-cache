`timescale 1ns / 1ps

`include "iob_cache.vh"
`include "iob_cache_conf.vh"

module iob_cache_write_channel
  #(
    parameter ADDR_W = `ADDR_W,
    parameter DATA_W = `DATA_W,
    parameter BE_ADDR_W = `BE_ADDR_W,
    parameter BE_DATA_W = `BE_DATA_W,
    parameter WRITE_POL  = `WRITE_THROUGH,
    parameter WORD_OFFSET_W = `WORD_OFFSET_W
    )
   (
    input                                                                      clk,
    input                                                                      reset,

    input                                                                      valid,
    input [ADDR_W-1 : `NBYTES_W + WRITE_POL*WORD_OFFSET_W]                    addr,
    input [`NBYTES-1:0]                                                      wstrb,
    input [DATA_W + WRITE_POL*(DATA_W*(2**WORD_OFFSET_W)-DATA_W)-1:0] wdata, // try [DATA_W*((2**WORD_OFFSET_W)**WRITE_POL)-1:0] (f(x)=a*b^x)
    output reg                                                                 ready,

    // Native Memory interface
    output [BE_ADDR_W -1:0]                                                    mem_addr,
    output reg                                                                 mem_valid,
    input                                                                      mem_ready,
    output [BE_DATA_W-1:0]                                                     mem_wdata,
    output reg [`BE_NBYTES-1:0]                                                 mem_wstrb
    );

   genvar                                                                      i;

   generate
      if (WRITE_POL == `WRITE_THROUGH) begin
        assign mem_addr = {BE_ADDR_W{1'b0}} + {addr[ADDR_W-1 : `BE_NBYTES_W], {`BE_NBYTES_W{1'b0}}};

         localparam
           idle  = 1'd0,
           write = 1'd1;

         reg [0:0] state;
         if (BE_DATA_W == DATA_W) begin
            assign mem_wdata = wdata;

            always @* begin
               mem_wstrb = 0;

               case (state)
                 write: mem_wstrb = wstrb;
                 default:;
               endcase
            end
         end else begin
            wire [`BE_NBYTES_W-`NBYTES_W -1 :0] word_align = addr[`NBYTES_W +: (`BE_NBYTES_W - `NBYTES_W)];

            for (i=0; i < BE_DATA_W/DATA_W; i=i+1) begin : wdata_block
               assign mem_wdata[(i+1)*DATA_W-1:i*DATA_W] = wdata;
            end

            always @* begin
               mem_wstrb = 0;

               case (state)
                 write: mem_wstrb = wstrb << word_align * `NBYTES;
                 default:;
               endcase
            end
         end

         always @(posedge clk, posedge reset) begin
            if (reset)
              state <= idle;
            else
              case (state)
                idle: begin
                   if (valid)
                     state <= write;
                   else
                     state <= idle;
                end
                default: begin // write
                   if (mem_ready & ~valid)
                     state <= idle;
                   else
                     if (mem_ready & valid) // still has data to write
                       state <= write;
                     else
                       state <= write;
                end
              endcase
         end

         always @* begin
            ready = 1'b0;
            mem_valid = 1'b0;

            case (state)
              idle:
                ready = 1'b1;
              default: begin // write
                 mem_valid = ~mem_ready;
                 ready = mem_ready;
              end
            endcase
         end
      end else begin // if (WRITE_POL == WRITE_BACK)
         if (LINE2BE_W > 0) begin
            reg [LINE2BE_W-1:0] word_counter, word_counter_reg;
            always @(posedge clk)
              word_counter_reg <= word_counter;

            // memory address
            assign mem_addr  = {BE_ADDR_W{1'b0}} + {addr[ADDR_W-1: `BE_NBYTES_W + `LINE2BE_W], word_counter, {`BE_NBYTES_W{1'b0}}};

            // memory write-data
            assign mem_wdata = wdata >> (BE_DATA_W * word_counter);

            localparam
              idle  = 1'd0,
              write = 1'd1;

            reg [0:0]            state;

            always @(posedge clk, posedge reset) begin
               if (reset)
                 state <= idle;
               else
                 case (state)
                   idle: begin
                      if (valid)
                        state <= write;
                      else
                        state <= idle;
                   end
                   default: begin // write
                      if (mem_ready & (&word_counter_reg))
                        state <= idle;
                      else
                        state <= write;
                   end
                 endcase
            end

            always @* begin
               ready        = 1'b0;
               mem_valid    = 1'b0;
               mem_wstrb    = 0;
               word_counter = 0;

               case (state)
                 idle: begin
                    ready = ~valid;
                    if (valid) mem_wstrb = {`BE_NBYTES{1'b1}};
                    else mem_wstrb =0;
                 end
                 default: begin // write
                    ready = mem_ready & (&word_counter); // last word transfered
                    mem_valid = ~(mem_ready & (&word_counter));
                    mem_wstrb = {`BE_NBYTES{1'b1}};
                    word_counter = word_counter_reg + mem_ready;
                 end
               endcase
            end
         end else begin // if (LINE2BE_W == 0)
            // memory address
            assign mem_addr  = {BE_ADDR_W{1'b0}} + {addr[ADDR_W-1: `BE_NBYTES_W], {`BE_NBYTES_W{1'b0}}};

            // memory write-data
            assign mem_wdata = wdata;

            localparam
              idle  = 1'd0,
              write = 1'd1;

            reg [0:0]            state;

            always @(posedge clk, posedge reset) begin
               if (reset)
                 state <= idle;
               else
                 case (state)
                   idle: begin
                      if (valid)
                        state <= write;
                      else
                        state <= idle;
                   end
                   default: begin // write
                      if (mem_ready)
                        state <= idle;
                      else
                        state <= write;
                   end
                 endcase
            end

            always @* begin
               ready     = 1'b0;
               mem_valid = 1'b0;
               mem_wstrb = 0;

               case (state)
                 idle: begin
                    ready = ~valid;
                    if (valid) mem_wstrb = {`BE_NBYTES{1'b1}};
                    else mem_wstrb = 0;
                 end
                 default: begin // write
                    ready = mem_ready;
                    mem_valid = ~mem_ready;
                    mem_wstrb = {`BE_NBYTES{1'b1}};
                 end
               endcase
            end
         end
      end
   endgenerate

endmodule
