`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"

module iob_cache_front_end #(
   parameter ADDR_W = 32,
   parameter DATA_W = 32,

   // Derived parameters DO NOT CHANGE
   parameter NBYTES       = DATA_W / 8,
   parameter USE_CTRL     = 0,
   parameter USE_CTRL_CNT = 0
) (
   // front-end port
   input                                clk_i,
   input                                reset,
   input [USE_CTRL + ADDR_W -1:0]       addr,
   input [ DATA_W-1:0]                  wdata,
   input [ NBYTES-1:0]                  wstrb,
   input                                valid,
   output [ DATA_W-1:0]                 rdata,
   output                               ack,
   output                               rvalid,
   output                               ready,

   // internal input signals
   output                               data_valid,
   output [ADDR_W-1:0]                  data_addr,
   input [DATA_W-1:0]                   data_rdata,
   input                                data_ack,

   // stored input signals
   output reg                           data_valid_reg,
   output reg [ADDR_W-1:0]              data_addr_reg,
   output reg [DATA_W-1:0]              data_wdata_reg,
   output reg [NBYTES-1:0]              data_wstrb_reg,

   // cache-control
   output                               ctrl_valid,
   output [`IOB_CACHE_SWREG_ADDR_W-1:0] ctrl_addr,
   input [ USE_CTRL*(DATA_W-1):0]       ctrl_rdata,
   input                                ctrl_ack
);

   wire data_valid_int;

   // select cache memory ir controller
   generate
      if (USE_CTRL) begin : g_ctrl
         // Front-end output signals
         assign ack          = ctrl_ack | data_ack;
         assign rdata        = (ctrl_ack) ? ctrl_rdata : data_rdata;

         assign data_valid_int = ~addr[USE_CTRL+ADDR_W-1] & valid;

         assign ctrl_valid     = addr[USE_CTRL+ADDR_W-1] & valid;
         assign ctrl_addr    = addr[`IOB_CACHE_SWREG_ADDR_W-1:0];

      end else begin : g_no_ctrl
         // Front-end output signals
         assign ack          = data_ack;
         assign rdata        = data_rdata;
         assign data_valid_int = valid;
         assign ctrl_valid     = 1'b0;
         assign ctrl_addr    = `IOB_CACHE_SWREG_ADDR_W'dx;
      end
   endgenerate

   // register inputs
   always @(posedge clk_i, posedge reset) begin
      if (reset) begin
         data_valid_reg   <= 0;
         data_addr_reg  <= 0;
         data_wdata_reg <= 0;
         data_wstrb_reg <= 0;
      end else begin
         data_valid_reg   <= data_valid_int;
         data_addr_reg  <= addr[ADDR_W-1:0];
         data_wdata_reg <= wdata;
         data_wstrb_reg <= wstrb;
      end
   end

   // data output ports
   assign data_addr = addr[ADDR_W-1 : 0];
   assign data_valid  = data_valid_int | data_valid_reg;


   //ctlr rvalid and ready
   reg ctrl_rvalid;
   always @(posedge clk_i, posedge reset) begin
      if (reset) begin
         ctrl_rvalid <= 0;
      end else begin
         ctrl_rvalid <= ctrl_valid & !wstrb;
      end
   end
   wire ctrl_ready = 1'b1;


   // data rvalid and ready
   reg last_access_was_read;

   always @(posedge clk_i, posedge reset) begin
      if (reset) begin
         last_access_was_read <= 0;
      end else begin
         last_access_was_read <= data_valid & !wstrb;
      end
   end

   wire data_rvalid = last_access_was_read & ack;

   // data ready is low if there was a request and it was not acked
  //computed by a state machine that tracks when the request was made
   reg data_ready, data_ready_nxt;
   always @(posedge clk_i, posedge reset) begin
      if (reset) begin
         data_ready <= 1'b1;
      end else begin
         data_ready <= data_ready_nxt;
      end
   end

   always @(*) begin
      data_ready_nxt = ((data_valid_reg | ~data_ready) & !data_ack) ? 1'b0 : 1'b1;
   end

   assign ready = ctrl_valid & ctrl_ready | data_valid & data_ready;
   assign rvalid = ctrl_rvalid | data_rvalid;
   
endmodule
