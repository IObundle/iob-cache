`timescale 1ns / 1ps
`include "iob-cache.vh"

module write_channel_native
  #(
    parameter FE_ADDR_W   = 32,
    parameter FE_DATA_W   = 32,
    parameter FE_NBYTES  = FE_DATA_W/8,
    parameter FE_BYTE_W = $clog2(FE_NBYTES), 
    parameter BE_ADDR_W = FE_ADDR_W, 
    parameter BE_DATA_W = FE_DATA_W,
    parameter BE_NBYTES = BE_DATA_W/8, 
    parameter BE_BYTE_W = $clog2(BE_NBYTES) 
    ) 
   (
    input                         clk,
    input                         reset,

    input                         valid,
    input [FE_ADDR_W-1:FE_BYTE_W] addr,
    input [FE_NBYTES-1:0]         wstrb,
    input [FE_DATA_W-1:0]         wdata,
    output reg                    ready,
    //Native Memory interface
    output [BE_ADDR_W -1:0]       mem_addr,
    output reg                    mem_valid,
    input                         mem_ready,
    output [BE_DATA_W-1:0]        mem_wdata,
    output reg [BE_NBYTES-1:0]    mem_wstrb
   
    );
   
   assign mem_addr = {BE_ADDR_W{1'b0}} + {addr[FE_ADDR_W-1:BE_BYTE_W], {BE_BYTE_W{1'b0}}}; 
   
   localparam
     idle  = 1'd0,
     write = 1'd1;
   
   reg [0:0]                      state;

   generate
      if(BE_DATA_W == FE_DATA_W)
        begin
           
           assign mem_wdata = wdata;
           
           always @*
             begin
                mem_wstrb = 0;
                case(state)
                  write:
                    begin
                       mem_wstrb = wstrb;
                    end
                  default:;
                endcase // case (state)
             end // always @ *
           
        end
      else
        begin
           
           wire [BE_BYTE_W-FE_BYTE_W -1 :0] word_align = addr[FE_BYTE_W +: (BE_BYTE_W - FE_BYTE_W)];
           
           assign mem_wdata = wdata << word_align * FE_DATA_W ;
           
           always @*
             begin
                mem_wstrb = 0;
                case(state)
                  write:
                    begin
                       mem_wstrb = wstrb << word_align * FE_NBYTES;
                    end
                  default:;
                endcase // case (state)
             end 
           
        end
   endgenerate


   
   always @(posedge clk, posedge reset)
     begin
        if(reset)
          state <= idle;
        else
          case(state)

            idle:
              begin
                 if(valid)
                   state <= write;
                 else
                   state <= idle;
              end

            write:
              begin
                 if(mem_ready & ~valid)
                   state <= idle;
                 else
                   if(mem_ready & valid) //still has data to write
                     state <= write;
                   else
                     state <= write;
              end

            default:;
          endcase // case (state)
     end // always @ (posedge clk, posedge reset)

   always @*
     begin
        ready = 1'b0;
        mem_valid = 1'b0;
        case(state)
          idle:
            ready = 1'b1;
          write:
            begin
               mem_valid = ~mem_ready;
               ready = mem_ready;
            end
          
          default:;
        endcase // case (state)
     end
   
   
endmodule
