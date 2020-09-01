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
    output [FE_ADDR_W-1:FE_BYTES_W]              addr_int,
    output [FE_DATA_W-1:0]                       wdata_int,
    output [FE_NBYTES-1:0]                       wstrb_int,
    input [FE_DATA_W-1:0]                        rdata_int,
    //stored input signals
    output reg [FE_ADDR_W-1:FE_BYTES_W]          addr_r,
    output reg [FE_DATA_W-1:0]                   wdata_r,
    output reg [FE_NBYTES-1:0]                   wstrb_r,
    output reg [FE_DATA_W-1:0]                   rdata_r,
    //back-end & memory signals
    output                                       global_wen,
    input                                        hit,
    input                                        buffer_full,
    input                                        buffer_empty,
    input                                        write_idle,
    output reg                                   read_miss,
    input                                        read_replace,
    //control
    output [`CTRL_ADDR_W-1:0]                    ctrl_task,
    output                                       ctrl_valid,
    input [FE_DATA_W-1:0]                        ctrl_data,
    input                                        ctrl_ready,
    output [1:0]                                 ctrl_status,
    output [`CTRL_CNT_W-1:0]                     ctrl_counter
    );

   wire                                          cache_select, ctrl_select;
   wire                                          write_access, read_access;
   assign addr_int = addr [FE_ADDR_W-1:FE_BYTES_W];
   assign wdata_int = wdata;
   assign wstrb_int = wstrb;
   wire                                          ready_int;
   

   //////////////////////////////////////////////////////////////////////////////////
     // Cache-selection - cache-memory or cache-control 
   /////////////////////////////////////////////////////////////////////////////////
   generate
      if(CTRL_CACHE) 
        begin
           //Cache - Controller selection
           always(posedge clk, posedge reset)
             if(reset)
               ctrl_select <=0;
             else if(valid)
               ctrl_select <= addr[CTRL_CACHE + FE_ADDR_W -1];
             else
               ctrl_select <= ctrl_select;
           
           assign ctrl_select = ctrl_select & valid_r;
           assign ctrl_valid  = addr[CTRL_CACHE + FE_ADDR_W -1] & valid; //no delays
           assign ctrl_task = addr[FE_BYTES_W +: `CTRL_ADDR_W];
           assign ctrl_status = {buffer_full,(buffer_empty & write_idle)};
           //Cache-memory 
           assign cache_select = ~ctrl_select & valid_r; 
           assign write_access = (cache_select &   (|wstrb_r));
           assign read_access  = (cache_select &  ~(|wstrb_r));
           //Output
           assign ready = (ctrl_select)? ctrl_ready : ready_int;
           assign rdata = (ctrl_select)? ctrl_data  : rdata_int;         
           
        end // if (CTRL_CACHE)
      else 
        begin
           //Cache-memoryu
           assign write_access = (valid_r &   (|wstrb_r));
           assign read_access =  (valid_R &  ~(|wstrb_r));
           
           assign rdata = rdata_int;
           assign ready = ready_int;    
           //Cache-control
           assign ctrl_valid = 1'bx;
           assign ctrl_task = `CTRL_ADDR_W'dx;
           assign ctrl_status = 2'dx;         
        end // else: !if(CTRL_CACHE)
   endgenerate

   //////////////////////////////////////////////////////////////////////////////////
   // Input stored signals
   /////////////////////////////////////////////////////////////////////////////////

   always @(posedge clk, posedge reset)
     begin
        if(reset)
          begin
             addr_r  <= 0;
             wdata_r <= 0;
             wstrb_r <= 0;
          end
        else
          if(valid) //updates
            begin
               addr_r  <= addr[FE_ADDR_W-1:FE_BYTES_W];
               wdata_r <= wdata;
               wstrb_r <= wstrb;
            end
          else 
            begin
               addr_r  <= addr_r;
               wdata_r <= wdata_r;
               wstrb_r <= wstrb_r;
            end // else: !if(valid)
     end // always @ (posedge clk, posedge reset)  

   always @(posedge clk, posedge reset)
     begin
        if(reset | (ready & ~valid)) // ready is a synchronous reset for internal valid signal (only if the input doesn have a new request in the same clock-cycle) - avoids repeated requests
          valid_r <= 0;
        else    
          if(valid) //updates
            valid_r <= valid;
          else
            valid_r <= valid_r;
     end // always @ (posedge clk, posedge reset)  
   

   //////////////////////////////////////////////////////////////////////////////////
   // Front-End FSM
   /////////////////////////////////////////////////////////////////////////////////


   assign  read_miss = valid_r & ~(|wstrb_r) & ~hit;
   assign  ready_int =  hit & read_access & ~read_replace) | (~buffer_full & write_access); 
   assign  global_wen = hit & read_access & ~read_replace) | (~buffer_full & write_access); 

   

   //////////////////////////////////////////////////////////////////////////////////
   // Cache-control's counters
   /////////////////////////////////////////////////////////////////////////////////

   generate
      if (CTRL_CACHE & CTRL_CNT)
        begin
           reg [`CTRL_COUNTER_W-1:0] ctrl_counter_r;
           
           always @ (posedge valid_r)
             if(read_access & hit)
               ctrl_counter_r <= `READ_HIT;
             else if(read_access & ~hit)
               ctrl_counter_r <= `READ_MISS;
             else if (write_access & hit)
               ctrl_counter_r <= `WRITE_HIT;
             else if(write_access & ~hit)
               ctrl_counter_r <= `WRITE_MISS;
             else
               ctrl_counter_r <= `CTRL_COUNTER_W'd0;
           
           assign ctrl_counter = ctrl_counter_r;          
        end
      else
        begin
           assign ctrl_counter = {`CTRL_COUNTER_W{1'bx}}; //Don't care, isn't used
        end // else: !if(CTRL_CACHE & CTRL_CNT)   
   endgenerate

   
endmodule
