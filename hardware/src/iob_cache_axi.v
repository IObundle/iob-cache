/*
 IOb-Cache top-level module for AXI4 back-end interface
 
 this top module is necessary as Verilog does not allow generate statements on ports; it is not possible t have a single top-level module for iob-native interface and AXI4
 */

`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "iob_cache.vh"
`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_axi
  #(
    parameter ADDR_W = `IOB_CACHE_ADDR_W,
    parameter DATA_W = `IOB_CACHE_DATA_W,
    parameter BE_ADDR_W = `IOB_CACHE_BE_ADDR_W,
    parameter BE_DATA_W = `IOB_CACHE_BE_DATA_W,
    parameter NWAYS_W = `IOB_CACHE_NWAYS_W,
    parameter NLINES_W = `IOB_CACHE_NLINES_W,
    parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
    parameter WTBUF_DEPTH_W = `IOB_CACHE_WTBUF_DEPTH_W,
    parameter REP_POLICY = `IOB_CACHE_PLRU_MRU,
    parameter WRITE_POL = `IOB_CACHE_WRITE_THROUGH,
    parameter USE_CTRL = `IOB_CACHE_USE_CTRL,
    parameter USE_CTRL_CNT = `IOB_CACHE_USE_CTRL_CNT,
    parameter AXI_ID_W = `IOB_CACHE_AXI_ID_W,
    parameter AXI_LEN_W = `IOB_CACHE_AXI_LEN_W,
    parameter AXI_ADDR_W = BE_ADDR_W,
    parameter AXI_DATA_W = BE_DATA_W,
    parameter [AXI_ID_W-1:0] AXI_ID = `IOB_CACHE_AXI_ID
   )
   (
    // Front-end interface (IOb native slave)
    `IOB_INPUT(req, 1),
    `IOB_INPUT(addr, USE_CTRL+ADDR_W-`IOB_CACHE_NBYTES_W),
    `IOB_INPUT(wdata, DATA_W),
    `IOB_INPUT(wstrb, `IOB_CACHE_NBYTES),
    `IOB_OUTPUT(rdata, DATA_W),
    `IOB_OUTPUT(ack, 1),

    // Cache invalidate and write-trough buffer IO chain
    `IOB_INPUT(invalidate_in, 1),    
    `IOB_OUTPUT(invalidate_out, 1), 
    `IOB_INPUT(wtb_empty_in, 1),
    `IOB_OUTPUT(wtb_empty_out, 1),

    // AXI4 back-end interface
`include "iob_cache_axi_m_port.vh"
    //General Interface Signals
    `IOB_INPUT(clk_i,          1), //System clock input
    `IOB_INPUT(rst_i,          1)  //System reset, asynchronous and active high
    );
   
   //Front-end & Front-end interface.
   wire                                         data_req, data_ack;
   wire [ADDR_W -1 : `IOB_CACHE_NBYTES_W]                 data_addr;
   wire [DATA_W-1 : 0]                          data_wdata, data_rdata;
   wire [`IOB_CACHE_NBYTES-1: 0]                          data_wstrb;
   wire [ADDR_W -1 : `IOB_CACHE_NBYTES_W]                 data_addr_reg;
   wire [DATA_W-1 : 0]                          data_wdata_reg;
   wire [`IOB_CACHE_NBYTES-1: 0]                          data_wstrb_reg;
   wire                                         data_req_reg;

   wire                                         ctrl_req, ctrl_ack;
   wire [`iob_cache_swreg_ADDR_W-1:0]                      ctrl_addr;
   wire [USE_CTRL*(DATA_W-1):0]                 ctrl_rdata;
   wire                                         ctrl_invalidate;

   wire                                         wtbuf_full, wtbuf_empty;

   assign invalidate_out = ctrl_invalidate | invalidate_in;
   assign wtb_empty_out = wtbuf_empty & wtb_empty_in;

   iob_cache_front_end
     #(
       .ADDR_W (ADDR_W-`IOB_CACHE_NBYTES_W),
       .DATA_W (DATA_W),
       .USE_CTRL(USE_CTRL)
       )
   front_end
     (
      .clk   (clk_i),
      .reset (rst_i),

      // front-end port
      .req (req),
      .addr  (addr),
      .wdata (wdata),
      .wstrb (wstrb),
      .rdata (rdata),
      .ack (ack),

      // cache-memory input signals
      .data_req (data_req),
      .data_addr  (data_addr),

      // cache-memory output
      .data_rdata (data_rdata),
      .data_ack (data_ack),

      // stored input signals
      .data_req_reg (data_req_reg),
      .data_addr_reg  (data_addr_reg),
      .data_wdata_reg (data_wdata_reg),
      .data_wstrb_reg (data_wstrb_reg),

      // cache-controller
      .ctrl_req (ctrl_req),
      .ctrl_addr  (ctrl_addr),
      .ctrl_rdata (ctrl_rdata),
      .ctrl_ack (ctrl_ack)
      );

   //Cache memory & This block implements the cache memory.
   wire                                         write_hit, write_miss, read_hit, read_miss;

   // back-end write-channel
   wire                                         write_req, write_ack;
   wire [ADDR_W-1 : `IOB_CACHE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr;
   wire [DATA_W + WRITE_POL*(DATA_W*(2**WORD_OFFSET_W)-DATA_W)-1 :0] write_wdata;
   wire [`IOB_CACHE_NBYTES-1:0]                                                write_wstrb;

   // back-end read-channel
   wire                                                              replace_req, replace;
   wire [ADDR_W -1 : `IOB_CACHE_BE_NBYTES_W+`IOB_CACHE_LINE2BE_W]                         replace_addr;
   wire                                                              read_req;
   wire [`IOB_CACHE_LINE2BE_W-1:0]                                             read_addr;
   wire [BE_DATA_W-1:0]                                              read_rdata;

   iob_cache_memory
     #(
       .ADDR_W (ADDR_W),
       .DATA_W (DATA_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .NWAYS_W (NWAYS_W),
       .NLINES_W (NLINES_W),
       .WORD_OFFSET_W (WORD_OFFSET_W),
       .WTBUF_DEPTH_W (WTBUF_DEPTH_W),
       .REP_POLICY (REP_POLICY),
       .WRITE_POL (WRITE_POL),
       .USE_CTRL(USE_CTRL),
       .USE_CTRL_CNT (USE_CTRL_CNT)
       )
   cache_memory
     (
      .clk   (clk_i),
      .reset (rst_i),

      // front-end
      .req (data_req),
      .addr (data_addr[ADDR_W-1 : `IOB_CACHE_BE_NBYTES_W+`IOB_CACHE_LINE2BE_W]),
      .rdata (data_rdata),
      .ack (data_ack),
      .req_reg (data_req_reg),
      .addr_reg (data_addr_reg),
      .wdata_reg (data_wdata_reg),
      .wstrb_reg (data_wstrb_reg),

      // back-end
      // write-through-buffer (write-channel)
      .write_req (write_req),
      .write_addr (write_addr),
      .write_wdata (write_wdata),
      .write_wstrb (write_wstrb),
      .write_ack (write_ack),

      // cache-line replacement (read-channel)
      .replace_req (replace_req),
      .replace_addr (replace_addr),
      .replace (replace),
      .read_req (read_req),
      .read_addr (read_addr),
      .read_rdata (read_rdata),

      // control's signals
      .wtbuf_empty (wtbuf_empty),
      .wtbuf_full (wtbuf_full),
      .write_hit (write_hit),
      .write_miss (write_miss),
      .read_hit (read_hit),
      .read_miss (read_miss),
      .invalidate (invalidate_out)
      );

   //Back-end interface & This block interfaces with the system level or next-level cache.
   iob_cache_back_end_axi
     #(
       .ADDR_W (ADDR_W),
       .DATA_W (DATA_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WORD_OFFSET_W(WORD_OFFSET_W),
       .WRITE_POL (WRITE_POL),
       .AXI_ADDR_W(AXI_ADDR_W),
       .AXI_DATA_W(AXI_DATA_W),
       .AXI_ID_W(AXI_ID_W),
       .AXI_LEN_W(AXI_LEN_W),
       .AXI_ID(AXI_ID)
      )
   back_end_axi
     (
      // write-through-buffer (write-channel)
      .write_valid (write_req),
      .write_addr (write_addr),
      .write_wdata (write_wdata),
      .write_wstrb (write_wstrb),
      .write_ready (write_ack),

      // cache-line replacement (read-channel)
      .replace_valid (replace_req),
      .replace_addr (replace_addr),
      .replace (replace),
      .read_valid (read_req),
      .read_addr (read_addr),
      .read_rdata (read_rdata),

      //back-end AXI4 interface
`include "iob_cache_axi_portmap.vh"
      .clk_i(clk_i),
      .rst_i(rst_i)  
      );

   //Cache control & Cache control block.
   generate
      if (USE_CTRL)
        iob_cache_control
          #(
            .DATA_W  (DATA_W),
            .USE_CTRL_CNT   (USE_CTRL_CNT)
            )
      cache_control
        (
         .clk   (clk_i),
         .reset (rst_i),

         // control's signals
         .valid (ctrl_req),
         .addr  (ctrl_addr),

         // write data
         .wtbuf_full  (wtbuf_full),
         .wtbuf_empty (wtbuf_empty),
         .write_hit   (write_hit),
         .write_miss  (write_miss),
         .read_hit    (read_hit),
         .read_miss   (read_miss),

         .rdata      (ctrl_rdata),
         .ready      (ctrl_ack),
         .invalidate (ctrl_invalidate)
         );
      else begin
         assign ctrl_rdata = 1'bx;
         assign ctrl_ack = 1'bx;
         assign ctrl_invalidate = 1'b0;
      end
   endgenerate

endmodule
