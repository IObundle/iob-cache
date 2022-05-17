`timescale 1ns / 1ps

`include "iob_cache.vh"

module iob_cache_front_end
  #(
    parameter ADDR_W   = 32,
    parameter DATA_W   = 32,

    // Derived parameters DO NOT CHANGE
    parameter NBYTES  = DATA_W/8,
    parameter CTRL_CACHE = 0,
    parameter CTRL_CNT = 0
    )
   (
    // front-end port
    input                            clk,
    input                            reset,
    input [CTRL_CACHE + ADDR_W -1:0] addr,
    input [DATA_W-1:0]               wdata,
    input [NBYTES-1:0]               wstrb,
    input                            req,
    output                           ack,
    output [DATA_W-1:0]              rdata,

    // internal input signals
    output                           data_req,
    output [ADDR_W-1:0]              data_addr,
    input [DATA_W-1:0]               data_rdata,
    input                            data_ack,

    // stored input signals
    output reg                       data_req_reg,
    output reg [ADDR_W-1:0]          data_addr_reg,
    output reg [DATA_W-1:0]          data_wdata_reg,
    output reg [NBYTES-1:0]          data_wstrb_reg,

    // cache-control
    output                           ctrl_req,
    output [`CTRL_ADDR_W-1:0]        ctrl_addr,
    input [CTRL_CACHE*(DATA_W-1):0]  ctrl_rdata,
    input                            ctrl_ack
    );

   wire                              data_req_int;

   // select cache memory ir controller
   generate
      if (CTRL_CACHE) begin
         // Front-end output signals
         assign ack   = ctrl_ack | data_ack;
         assign rdata = (ctrl_ack)? ctrl_rdata  : data_rdata;

         assign data_req_int = ~addr[CTRL_CACHE + ADDR_W -1] & req;

         assign ctrl_req  = addr[CTRL_CACHE + ADDR_W -1] & req;
         assign ctrl_addr = addr[`CTRL_ADDR_W-1:0];

      end else begin
         // Front-end output signals
         assign ack = data_ack;
         assign rdata = data_rdata;
         assign data_req_int = req;
         assign ctrl_req = 1'bx;
         assign ctrl_addr = `CTRL_ADDR_W'dx;
      end
   endgenerate

   // register inputs
   always @(posedge clk, posedge reset) begin
      if (reset) begin
         data_req_reg   <= 0;
         data_addr_reg  <= 0;
         data_wdata_reg <= 0;
         data_wstrb_reg <= 0;
      end else begin
         data_req_reg   <= data_req_int;
         data_addr_reg  <= addr[ADDR_W-1:0];
         data_wdata_reg <= wdata;
         data_wstrb_reg <= wstrb;
      end
   end

   // data output ports
   assign data_addr = addr[ADDR_W-1 : 0];
   assign data_req  = data_req_int | data_req_reg;

endmodule