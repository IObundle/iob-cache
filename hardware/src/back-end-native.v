`timescale 1ns / 1ps
`include "iob-cache.vh"

module back_end_native
    #(
      //memory cache's parameters
      parameter FE_ADDR_W   = 32,       //Address width - width of the Master's entire access address (including the LSBs that are discarded, but discarding the Controller's)
      parameter FE_DATA_W   = 32,       //Data width - word size used for the cache
      parameter WORD_OFF_W = 3,      //Word-Offset Width - 2**OFFSET_W total FE_DATA_W words per line - WARNING about LINE2MEM_W (can cause word_counter [-1:0]
      parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
      parameter BE_DATA_W = FE_DATA_W, //Data width of the memory

      parameter FE_NBYTES  = FE_DATA_W/8,        //Number of Bytes per Word
      parameter FE_BYTE_W  = $clog2(FE_NBYTES), //Byte Offset
      /*---------------------------------------------------*/
      //Higher hierarchy memory (slave) interface parameters 

      parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
      parameter BE_BYTE_W = $clog2(BE_NBYTES), //Offset of Number of Bytes
      //Cache-Memory base Offset
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W)
   
    ) 
   (
    input                                        clk,
    input                                        reset,
    //write-through-buffer
    input                                        write_valid,
    input [FE_ADDR_W -1: FE_BYTE_W]              write_addr,
    input [FE_DATA_W-1:0]                        write_wdata,
    input [FE_NBYTES-1:0]                        write_wstrb,
    output                                       write_ready,
    //cache-line replacement
    input                                        replace_valid,
    input [FE_ADDR_W -1: FE_BYTE_W + WORD_OFF_W] replace_addr,
    output                                       replace_ready,
    output                                       read_valid,
    output [LINE2MEM_W -1:0]                     read_addr,
    output [BE_DATA_W -1:0]                      read_rdata,
    //back-end memory interface
    output                                       mem_valid,
    output [BE_ADDR_W -1:0]                      mem_addr,
    output [BE_DATA_W-1:0]                       mem_wdata,
    output [BE_NBYTES-1:0]                       mem_wstrb,
    input [BE_DATA_W-1:0]                        mem_rdata,
    input                                        mem_ready
  );

   wire [BE_ADDR_W-1:0]                          mem_addr_read,  mem_addr_write;
   wire                                          mem_valid_read, mem_valid_write;

   assign mem_addr =  (mem_valid_read)? mem_addr_read : mem_addr_write;
   assign mem_valid = mem_valid_read | mem_valid_write;                   
   
   
   read_channel_native
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),  
       .WORD_OFF_W(WORD_OFF_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W)
       )
   read_fsm
     (
      .clk(clk),
      .reset(reset),
      .replace_valid (replace_valid),
      .replace_addr (replace_addr),
      .replace_ready (replace_ready),
      .read_valid (read_valid),
      .read_addr (read_addr),
      .read_rdata (read_rdata),
      .mem_addr(mem_addr_read),
      .mem_valid(mem_valid_read),
      .mem_ready(mem_ready),
      .mem_rdata(mem_rdata)  
      );

   write_channel_native
     #(
       .FE_ADDR_W(FE_ADDR_W),
       .FE_DATA_W(FE_DATA_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W)
       )
   write_fsm
     (
      .clk(clk),
      .reset(reset),
      .valid (write_valid),
      .addr (write_addr),
      .wstrb (write_wstrb),
      .wdata (write_wdata),
      .ready (write_ready),
      .mem_addr(mem_addr_write),
      .mem_valid(mem_valid_write),
      .mem_ready(mem_ready),
      .mem_wdata(mem_wdata),
      .mem_wstrb(mem_wstrb)
      );
   
endmodule // back_end_native



module read_channel_native
  #(
    parameter FE_ADDR_W   = 32,
    parameter FE_DATA_W   = 32,
    parameter FE_NBYTES  = FE_DATA_W/8,
    parameter WORD_OFF_W = 3,
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTE_W = $clog2(BE_NBYTES), //Offset of the Number of Bytes
    //Cache-Memory base Offset
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W) //burst offset based on the cache word's and memory word size
    )
   (
    input                                                   clk,
    input                                                   reset,
    input                                                   replace_valid,
    input [FE_ADDR_W -1: BE_BYTE_W + LINE2MEM_W] replace_addr,
    output reg                                              replace_ready,
    output                                                  read_valid,
    output reg [LINE2MEM_W-1:0]                             read_addr,
    output [BE_DATA_W-1:0]                                  read_rdata,
    //Native memory interface
    output [BE_ADDR_W -1:0]                                 mem_addr,
    output reg                                              mem_valid,
    input                                                   mem_ready,
    input [BE_DATA_W-1:0]                                   mem_rdata
    );

   generate
      if (LINE2MEM_W > 0)
        begin

           reg [LINE2MEM_W-1:0] word_counter;
           
           assign mem_addr  = {BE_ADDR_W{1'b0}} + {replace_addr[FE_ADDR_W -1: BE_BYTE_W + LINE2MEM_W], word_counter, {BE_BYTE_W{1'b0}}};
           

           assign read_valid = mem_valid; //doesn require line_load since when mem_valid is HIGH, so is line_load.
           assign read_rdata = mem_rdata;

           localparam
             idle             = 2'd0,
             handshake        = 2'd1, //the process was divided in 2 handshake steps to cause a delay in the
             end_handshake    = 2'd2; //(always 1 or a delayed valid signal), otherwise it will fail

           always @ (posedge clk)
             read_addr <= word_counter;
           
           reg [1:0]                                  state;

           always @(posedge clk, posedge reset)
             begin
                if(reset)
                  begin
                     state <= idle;
                     
                  end
                else
                  begin
                     case(state)

                       idle:
                         begin
                            if(replace_valid) //main_process flag
                              state <= handshake;                                        
                            else
                              state <= idle;                      
                         end
                       
                       handshake:
                         begin
                            if(mem_ready)
                              if(read_addr == {LINE2MEM_W{1'b1}})
                                state <= end_handshake;
                              else
                                begin
                                   state <= handshake;
                                end
                            else
                              begin
                                 state <= handshake;
                              end
                         end
                       
                       end_handshake: //read-latency delay (last line word)
                         begin
                            state <= idle;
                         end
                       
                       default:;
                       
                     endcase                                                     
                  end         
             end
           
           
           always @*
             begin 
                //word_counter =0;
                
                case(state)
                  
                  idle:
                    begin
                       mem_valid = 1'b0;
                       replace_ready = 1'b0;
                       word_counter = 0;
                    end

                  handshake:
                    begin
                       mem_valid = 1'b1;
                       replace_ready = 1'b1;
                       word_counter = word_counter + read_valid;
                    end
                  
                  end_handshake:
                    begin
                       word_counter = word_counter;
                       replace_ready = 1'b1; //delay for read-latency
                       mem_valid = 1'b0;
                    end
                  
                  default:
                    begin
                       replace_ready = 1'b0;
                       mem_valid = 1'b0;
                       word_counter = 0;
                    end
                  
                endcase
             end
        end // if (LINE2MEM_W > 0)
      else
        begin
           assign mem_addr  = {BE_ADDR_W{1'b0}} + {replace_addr[FE_ADDR_W-1: BE_BYTE_W], {BE_BYTE_W{1'b0}}};
           
           assign read_valid = mem_valid; //doesn require line_load since when mem_valid is HIGH, so is line_load.
           assign read_rdata = mem_rdata;

           localparam
             idle             = 2'd0,
             handshake        = 2'd1, //the process was divided in 2 handshake steps to cause a delay in the
             end_handshake    = 2'd2; //(always 1 or a delayed valid signal), otherwise it will fail
           
           
           reg [1:0]                                  state;

           always @(posedge clk, posedge reset)
             begin
                if(reset)
                  state <= idle;
                else
                  begin
                     case(state)

                       idle:
                         begin
                            
                            if(read_miss) //main_process flag
                              state <= handshake;                                        
                            else
                              state <= idle;                      
                         end
                       
                       handshake:
                         begin
                            if(mem_ready)
                              state <= end_handshake;
                            else
                              state <= handshake;
                         end
                       
                       end_handshake: //read-latency delay (last line word)
                         begin
                            state <= idle;
                            word_counter <= 0;
                         end
                       
                       default:;
                       
                     endcase                                                     
                  end         
             end
           
           
           always @*
             begin 
                
                
                case(state)
                  
                  idle:
                    begin
                       mem_valid = 1'b0;
                       replace_ready = 1'b0;
                    end

                  handshake:
                    begin
                       mem_valid = 1'b1;
                       replace_ready = 1'b1;
                    end
                  
                  end_handshake:
                    begin
                       replace_ready = 1'b1; //delay for read-latency
                       mem_valid = 1'b0;
                    end
                  
                  default:;
                  
                endcase
             end
           
        end // else: !if(MEM_OFF_W > 0)
   endgenerate
   
endmodule // read_process_native




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
   
   assign mem_addr = {BE_ADDR_W{1'b0}} + {addr, {BE_BYTE_W{1'b0}}}; 
   
   localparam
     idle          = 3'd0,
     init_process  = 3'd1,
     write_process = 3'd2;
   
   reg [1:0]                                              state;

   generate
      if(BE_DATA_W == FE_DATA_W)
        begin
           
           assign mem_wdata = wdata;
           
           always @*
             begin
                mem_wstrb = 0;
                case(state)
                  write_process:
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
           
           assign mem_wdata = addr << word_align * FE_DATA_W ;
           
           always @*
             begin
                mem_wstrb = 0;
                case(state)
                  write_process:
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
                   state <= write_process;
                 else
                   state <= idle;
              end

            write_process:
              begin
                 if(mem_ready)
                   state <= idle;
                 else
                   state <= write_process;
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
          write_process:
            mem_valid = 1'b1;
          default:;
        endcase // case (state)
     end
   
   
endmodule

