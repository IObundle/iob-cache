`timescale 1ns / 1ps
`include "iob-cache.vh"

module front_end
  #(
    parameter FE_ADDR_W   = 32,       //Address width - width that will used for the cache 
    parameter FE_DATA_W   = 32,       //Data width - word size used for the cache

    //Do NOT change - memory cache's parameters - dependency
    parameter FE_NBYTES  = FE_DATA_W/8,       //Number of Bytes per Word
    parameter FE_BYTE_W = $clog2(FE_NBYTES), //Offset of the Number of Bytes per Word
    //Control's options
    parameter CTRL_CACHE = 0,
    parameter CTRL_CNT = 0
    )
   (
    //front-end port
    input                                       clk,
    input                                       reset,
`ifdef WORD_ADDR   
    input [CTRL_CACHE + FE_ADDR_W -1:FE_BYTE_W] addr, //MSB is used for Controller selection
`else
    input [CTRL_CACHE + FE_ADDR_W -1:0]         addr, //MSB is used for Controller selection
`endif
    input [FE_DATA_W-1:0]                       wdata,
    input [FE_NBYTES-1:0]                       wstrb,
    input                                       valid,
    output                                      ready,
    output [FE_DATA_W-1:0]                      rdata,

    //internal input signals
    output reg                                  data_valid,
    output reg [FE_ADDR_W-1:FE_BYTE_W]          data_addr,
    output reg [FE_DATA_W-1:0]                  data_wdata,
    output reg [FE_NBYTES-1:0]                  data_wstrb,
    input [FE_DATA_W-1:0]                       data_rdata,
    input                                       data_ready,
    //stored input signals
    output                                      data_valid_reg,
    output [FE_ADDR_W-1:FE_BYTE_W]              data_addr_reg,
    output [FE_DATA_W-1:0]                      data_wdata_reg,
    output [FE_NBYTES-1:0]                      data_wstrb_reg,
    //cache-control
    output                                      ctrl_valid,
    output [`CTRL_ADDR_W-1:0]                   ctrl_addr, 
    input [CTRL_CACHE*(FE_DATA_W-1):0]          ctrl_rdata,
    input                                       ctrl_ready
    );

   wire                                         valid_int;
   
   reg                                          valid_reg;
   reg [FE_ADDR_W-1:FE_BYTE_W]                  addr_reg;
   reg [FE_DATA_W-1:0]                          wdata_reg;
   reg [FE_NBYTES-1:0]                          wstrb_reg;

   assign data_valid_reg = valid_reg;
   assign data_addr_reg = addr_reg;
   assign data_wdata_reg = wdata_reg;
   assign data_wstrb_reg = wstrb_reg;


   wire                                         reset_valid_reg = ~valid_int & data_ready;
   
   
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
           
           assign ctrl_addr   = addr[FE_BYTE_W +: `CTRL_ADDR_W];
           
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
             addr_reg  <= 0;
             wdata_reg <= 0;
             wstrb_reg <= 0;
          end
        else
          if(valid_int) //updates
            begin
               addr_reg  <= addr[FE_ADDR_W-1:FE_BYTE_W];
               wdata_reg <= wdata;
               wstrb_reg <= wstrb;
            end
          else 
            begin
               addr_reg  <= addr_reg;
               wdata_reg <= wdata_reg;
               wstrb_reg <= wstrb_reg;
            end// else: !if(valid)
     end // always @ (posedge clk, posedge reset)  

   
   always @(posedge clk, posedge reset)
     begin
        if(reset)
          valid_reg <= 0;
        else
          if (reset_valid_reg)// ready is a synchronous reset for internal valid signal (only if the input doesn have a new request in the same clock-cycle) - avoids repeated requests
            valid_reg <= 0;
          else
            if(valid_int) //updates
              valid_reg <= valid_int;
            else
              valid_reg <= valid_reg;
     end // always @ (posedge clk, posedge reset)  


   //////////////////////////////////////////////////////////////////////////////////
   // Data Input Multiplexer
   /////////////////////////////////////////////////////////////////////////////////

   always @(*)
     begin
        //if(valid & ~(data_valid_reg & (|data_wstrb_reg))) //the input is valid, but the current task is a write, maintains the write input data, and prevents RAW hazards by delaying the read in 1 clock-clycle
        if(valid) 
        begin
             data_addr  = addr[FE_ADDR_W-1:FE_BYTE_W];
             data_wdata = wdata;
             data_wstrb = wstrb;
             data_valid = valid_int;
          end
        else
          begin
             data_addr  = data_addr_reg;
             data_wdata = data_wdata_reg;
             data_wstrb = data_wstrb_reg;
             data_valid = data_valid_reg;
          end // else: !if(valid & ~(data_valid_reg & (|data_wstrb_reg)))
     end
   
endmodule
