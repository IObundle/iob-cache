`timescale 1ns / 1ps
`include "iob-cache.vh"

module front_end
  #(
    parameter FE_ADDR_W   = 32,       //Address width - width that will used for the cache 
    parameter FE_DATA_W   = 32,       //Data width - word size used for the cache

    //Do NOT change - memory cache's parameters - dependency
    parameter FE_NBYTES  = FE_DATA_W/8,       //Number of Bytes per Word
    parameter FE_BYTES_W = $clog2(FE_NBYTES), //Offset of the Number of Bytes per Word

    //Control's options
    parameter CTRL_CACHE = 0,
    parameter CTRL_CNT = 0
    )
   (
    //front-end port
    input                                        clk,
    input                                        reset,
`ifdef WORD_ADDR   
    input [CTRL_CACHE + FE_ADDR_W -1:FE_BYTES_W] addr, //MSB is used for Controller selection
`else
    input [CTRL_CACHE + FE_ADDR_W -1:0]          addr, //MSB is used for Controller selection
`endif
    input [FE_DATA_W-1:0]                        wdata,
    input [FE_NBYTES-1:0]                        wstrb,
    input                                        valid,
    output                                       ready,
    output [FE_DATA_W-1:0]                       rdata,

    //internal input signals
    output                                       data_valid,
    output [FE_ADDR_W-1:FE_BYTES_W]              data_addr,
    output [FE_DATA_W-1:0]                       data_wdata,
    output [FE_NBYTES-1:0]                       data_wstrb,
    input [FE_DATA_W-1:0]                        data_rdata,
    input                                        data_ready,
    //stored input signals
    output reg                                   data_valid_reg,
    output reg [FE_ADDR_W-1:FE_BYTES_W]          data_addr_reg,
    output reg [FE_DATA_W-1:0]                   data_wdata_reg,
    output reg [FE_NBYTES-1:0]                   data_wstrb_reg,
    output reg [FE_DATA_W-1:0]                   data_rdata_reg,
    //cache-control
    output                                       ctrl_valid,
    output [`CTRL_ADDR_W-1:0]                    ctrl_addr, 
    input [FE_DATA_W-1:0]                        ctrl_rdata,
    input                                        ctrl_ready,
    );

   wire                                          valid_int;
     
   //////////////////////////////////////////////////////////////////////////////////
     //    Cache-selection - cache-memory or cache-control 
   /////////////////////////////////////////////////////////////////////////////////
   generate
      if(CTRL_CACHE) 
        begin

           //Front-end output signals
           assign ready = ctrl_ready | data_ready;
           
           assign rdata = (ctrl_ready)? ctrl_rdata  : data_rdata;     
           
           assign valid_int = ~addr[CTRL_CACHE + FE_ADDR_W -1] & valid;
           assign ctrl_valid = addr[CTRL_CACHE + FE_ADDR_W -1] & valid;       
           
           assign ctrl_addr   = addr[FE_BYTES_W +: `CTRL_ADDR_W];
           
        end // if (CTRL_CACHE)
      else 
        begin
           //Front-end output signals
           assign ready = data_ready; 
           
           assign rdata = data_rdata;
  
           assign valid_int = valid;
           
           assign ctrl_valid = 1'bx;
           
           assign ctrl_addr = `CTRL_ADDR_W'dx;
        
        end // else: !if(CTRL_CACHE)
   endgenerate

   //////////////////////////////////////////////////////////////////////////////////
   // Input Data stored signals
   /////////////////////////////////////////////////////////////////////////////////

   always @(posedge clk, posedge reset)
     begin
        if(reset)
          begin
             data_addr_reg  <= 0;
             data_wdata_reg <= 0;
             data_wstrb_reg <= 0;
          end
        else
          if(valid) //updates
            begin
               data_addr_reg  <= addr[FE_ADDR_W-1:FE_BYTES_W];
               data_wdata_reg <= wdata;
               data_wstrb_reg <= wstrb;
            end
          else 
            begin
               data_addr_reg  <= addr_reg;
               data_wdata_reg <= wdata_reg;
               data_wstrb_reg <= wstrb_reg;
            end // else: !if(valid)
     end // always @ (posedge clk, posedge reset)  

   
   always @(posedge clk, posedge reset)
     begin
        if(reset | (data_ready & ~(valid_int))) // ready is a synchronous reset for internal valid signal (only if the input doesn have a new request in the same clock-cycle) - avoids repeated requests
          data_valid_reg <= 0;
        else    
          if(valid) //updates
            data_valid_reg <= valid_int;
          else
            data_valid_reg <= valid_reg;
     end // always @ (posedge clk, posedge reset)  


   //////////////////////////////////////////////////////////////////////////////////
   // Data Input Multiplexer
   /////////////////////////////////////////////////////////////////////////////////

   always @(*)
     begin
        if(valid & ~(data_valid_reg & (|data_wstrb_reg))) //the input is valid, but the current task is a write, maintains the write input data, and prevents RAW hazards by delaying the read in 1 clock-clycle
          begin
             data_addr =  addr[FE_ADDR_W-1:FE_BYTES_W];
             data_wdata = wdata;
             data_wstrb = wstrb;
             data_valid = valid_int;
          end
        else
          begin
             data_addr =  data_addr_reg;
             data_wdata = data_wdata_reg;
             data_wstrb = data_wstrb_reg;
             data_valid = data_valid_reg;
          end // else: !if(valid & ~(data_valid_reg & (|data_wstrb_reg)))
     end
   
endmodule
