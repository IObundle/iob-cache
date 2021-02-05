`timescale 1ns / 1ps
`include "iob-cache.vh"

module write_channel_native
  #(
    parameter FE_ADDR_W = 32,
    parameter FE_DATA_W = 32,
    parameter FE_NBYTES = FE_DATA_W/8,
    parameter FE_BYTE_W = $clog2(FE_NBYTES), 
    parameter BE_ADDR_W = FE_ADDR_W, 
    parameter BE_DATA_W = FE_DATA_W,
    parameter BE_NBYTES = BE_DATA_W/8, 
    parameter BE_BYTE_W = $clog2(BE_NBYTES),    
    // Write-Policy
    parameter WRITE_POL  = `WRITE_THROUGH, //write policy: write-through (0), write-back (1)
    parameter WORD_OFF_W = 3, //required for write-back
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W) //burst offset based on the cache and memory word size
    ) 
   (
    input                                                                   clk,
    input                                                                   reset,

    input                                                                   valid,
    input [FE_ADDR_W-1:FE_BYTE_W + WRITE_POL*WORD_OFF_W]                    addr,
    input [FE_NBYTES-1:0]                                                   wstrb,
    input [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFF_W)-FE_DATA_W)-1:0] wdata, //try [FE_DATA_W*((2**WORD_OFF_W)**WRITE_POL)-1:0] (f(x)=a*b^x)
    output reg                                                              ready,
    //Native Memory interface
    output [BE_ADDR_W -1:0]                                                 mem_addr,
    output reg                                                              mem_valid,
    input                                                                   mem_ready,
    output [BE_DATA_W-1:0]                                                  mem_wdata,
    output reg [BE_NBYTES-1:0]                                              mem_wstrb
   
    );
   
   genvar                                                                   i;
   
   generate
      if(WRITE_POL == `WRITE_THROUGH) begin
         
         assign mem_addr = {BE_ADDR_W{1'b0}} + {addr[FE_ADDR_W-1:BE_BYTE_W], {BE_BYTE_W{1'b0}}}; 
         
         localparam
           idle  = 1'd0,
           write = 1'd1;
         
         reg [0:0]                      state;
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
              
              for (i = 0; i < BE_DATA_W/FE_DATA_W; i = i +1)
                assign mem_wdata[(i+1)*FE_DATA_W-1:i*FE_DATA_W] = wdata;
              
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
      end // if (WRITE_POL == WRITE_THROUGH)
      //////////////////////////////////////////////////////////////////////////////////////////////
      else begin // if (WRITE_POL == WRITE_BACK)

         if (LINE2MEM_W > 0) begin
            
            reg [LINE2MEM_W-1:0] word_counter, word_counter_reg;
            always @(posedge clk) word_counter_reg <= word_counter;
            
            // memory address
            assign mem_addr  = {BE_ADDR_W{1'b0}} + {addr[FE_ADDR_W-1: BE_BYTE_W + LINE2MEM_W], word_counter, {BE_BYTE_W{1'b0}}};
            // memory write-data
            assign mem_wdata = wdata>>(BE_DATA_W*word_counter);
            
            localparam
              idle  = 1'd0,
              write = 1'd1;
            
            reg [0:0]            state;

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
                          if(mem_ready & (&word_counter_reg))
                            state <= idle;
                          else
                            state <= write;
                       end

                     default:;
                   endcase // case (state)
              end // always @ (posedge clk, posedge reset)

            always @*
              begin
                 ready        = 1'b0;
                 mem_valid    = 1'b0;
                 mem_wstrb    = 0;
                 word_counter = 0;
                 
                 case(state)
                   idle:
                     begin
                        ready = ~valid;
                        if(valid) mem_wstrb = {BE_NBYTES{1'b1}};
                        else mem_wstrb =0;
                     end
                   
                   write:
                     begin
                        ready = mem_ready & (&word_counter); //last word transfered
                        mem_valid = ~(mem_ready & (&word_counter));
                        mem_wstrb = {BE_NBYTES{1'b1}};
                        word_counter = word_counter_reg + mem_ready;
                     end
                   
                   default:;
                 endcase // case (state)
              end
            
         end // if (LINE2MEM_W > 0)
         else begin // if (LINE2MEM_W == 0)
            
            // memory address
            assign mem_addr  = {BE_ADDR_W{1'b0}} + {addr[FE_ADDR_W-1: BE_BYTE_W], {BE_BYTE_W{1'b0}}};
            // memory write-data
            assign mem_wdata = wdata;
            
            localparam
              idle  = 1'd0,
              write = 1'd1;
            
            reg [0:0]            state;

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
                          if(mem_ready)
                            state <= idle;
                          else
                            state <= write;
                       end

                     default:;
                   endcase // case (state)
              end // always @ (posedge clk, posedge reset)

            always @*
              begin
                 ready        = 1'b0;
                 mem_valid    = 1'b0;
                 mem_wstrb    = 0;
                 
                 case(state)
                   idle:
                     begin
                        ready = ~valid;
                        if(valid) mem_wstrb = {BE_NBYTES{1'b1}};
                        else mem_wstrb = 0;
                     end
                   
                   write:
                     begin
                        ready = mem_ready;
                        mem_valid = ~mem_ready;
                        mem_wstrb = {BE_NBYTES{1'b1}};
                     end
                   
                   default:;
                 endcase // case (state)
              end // always @ *
            
         end // else: !if(LINE2MEM_W > 0)
      end // else: !if(WRITE_POL == WRITE_THROUGH)
   endgenerate
   
endmodule

