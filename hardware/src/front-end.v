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
    output                                       valid_int,
    output [FE_ADDR_W-1:FE_BYTES_W]              addr_int,
    output [FE_DATA_W-1:0]                       wdata_int,
    output [FE_NBYTES-1:0]                       wstrb_int,
    input [FE_DATA_W-1:0]                        rdata_int,
    //stored input signals
    output reg                                   valid_reg,
    output reg [FE_ADDR_W-1:FE_BYTES_W]          addr_reg,
    output reg [FE_DATA_W-1:0]                   wdata_reg,
    output reg [FE_NBYTES-1:0]                   wstrb_reg,
    output reg [FE_DATA_W-1:0]                   rdata_reg,
    //back-end & memory signals
    input                                        hit,
    input                                        buffer_full,
    //cache-control
    output                                       ctrl_valid,
    output [`CTRL_ADDR_W-1:0]                    ctrl_addr, 
    input [FE_DATA_W-1:0]                        ctrl_rdata,
    input                                        ctrl_ready,
    );

   wire                                          cache_select, ctrl_select;
   wire                                          write_access, read_access;  
   wire                                          ready_int;

   assign addr_int  = addr [FE_ADDR_W-1:FE_BYTES_W];
   assign wdata_int = wdata;
   assign wstrb_int = wstrb;
   
   //////////////////////////////////////////////////////////////////////////////////
     // Front-End cache-memory READY 
   /////////////////////////////////////////////////////////////////////////////////

   assign  ready_int =  hit & read_access & ~read_replace) | (~buffer_full & write_access); 

   //////////////////////////////////////////////////////////////////////////////////
   // Cache-selection - cache-memory or cache-control 
   /////////////////////////////////////////////////////////////////////////////////
   generate
      if(CTRL_CACHE) 
        begin

           //Front-end output signals
           assign ready = (ctrl_select)? ctrl_ready : ready_int;
           assign rdata = (ctrl_select)? ctrl_data  : rdata_int;     
           assign valid_int = ~addr[CTRL_CACHE + FE_ADDR_W -1] & valid;
           
           //Cache - Controller selection
           always(posedge clk, posedge reset)
             if(reset)
               ctrl_select <=0;
             else if(valid)
               ctrl_select <= addr[CTRL_CACHE + FE_ADDR_W -1];
             else
               ctrl_select <= ctrl_select;

           
           assign ctrl_select = ctrl_select & valid_reg;
           assign ctrl_valid  = addr[CTRL_CACHE + FE_ADDR_W -1] & valid; //no delays
           assign ctrl_addr   = addr[FE_BYTES_W +: `CTRL_ADDR_W];
           assign ctrl_status = {buffer_full,(buffer_empty & write_idle)};
           
           //Cache-memory 
           assign cache_select = ~ctrl_select & valid_reg; 
           assign write_access = (cache_select &   (|wstrb_reg));
           assign read_access  = (cache_select &  ~(|wstrb_reg));    
           
        end // if (CTRL_CACHE)
      else 
        begin
           //Front-end output signals
           assign rdata = rdata_int;
           assign ready = ready_int; 
           assign valid_int = valid;
           
           //Cache-memory
           assign write_access = (valid_reg &   (|wstrb_reg));
           assign read_access =  (valid_reg &  ~(|wstrb_reg));
           
           //Cache-control
           assign ctrl_valid = 1'bx;
           assign ctrl_addr = `CTRL_ADDR_W'dx;
        end // else: !if(CTRL_CACHE)
   endgenerate

   //////////////////////////////////////////////////////////////////////////////////
   // Input stored signals
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
          if(valid) //updates
            begin
               addr_reg  <= addr[FE_ADDR_W-1:FE_BYTES_W];
               wdata_reg <= wdata;
               wstrb_reg <= wstrb;
            end
          else 
            begin
               addr_reg  <= addr_reg;
               wdata_reg <= wdata_reg;
               wstrb_reg <= wstrb_reg;
            end // else: !if(valid)
     end // always @ (posedge clk, posedge reset)  

   
   always @(posedge clk, posedge reset)
     begin
        if(reset | (ready & ~valid)) // ready is a synchronous reset for internal valid signal (only if the input doesn have a new request in the same clock-cycle) - avoids repeated requests
          valid_reg <= 0;
        else    
          if(valid) //updates
            valid_reg <= valid;
          else
            valid_reg <= valid_reg;
     end // always @ (posedge clk, posedge reset)  
   
endmodule
