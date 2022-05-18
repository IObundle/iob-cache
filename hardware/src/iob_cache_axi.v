`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "iob_cache.vh"

module iob_cache_axi
  #(
    parameter FE_ADDR_W = `ADDR_W,
    parameter FE_DATA_W = `DATA_W,
    parameter BE_ADDR_W = FE_ADDR_W,
    parameter BE_DATA_W = `DATA_W,
    parameter NWAYS_W = 1,
    parameter NLINES_W = 7,
    parameter WORD_OFFSET_W = 3,
    parameter WTBUF_DEPTH_W = 5,
    parameter REP_POLICY = `PLRU_MRU,
    parameter WRITE_POL = `WRITE_THROUGH,
    parameter CTRL_CACHE = 0,
    parameter CTRL_CNT = 0,

    // Derived parameters DO NOT CHANGE
    parameter FE_NBYTES = FE_DATA_W/8,
    parameter FE_NBYTES_W = $clog2(FE_NBYTES),
    parameter BE_NBYTES = BE_DATA_W/8,
    parameter BE_NBYTES_W = $clog2(BE_NBYTES),
    parameter LINE2BE_W = WORD_OFFSET_W-$clog2(BE_DATA_W/FE_DATA_W), // line over back-end number of words ratio (log2)

    // AXI specific parameters
    parameter AXI_ID_W = 1,             // AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0 // AXI ID value
    )
   (
    // Front-end interface (IOb native slave)
    `IOB_INPUT(req, 1),
    `IOB_INPUT(addr, CTRL_CACHE+FE_ADDR_W-FE_NBYTES_W),
    `IOB_INPUT(wdata, FE_DATA_W),
    `IOB_INPUT(wstrb, FE_NBYTES),
    `IOB_OUTPUT(rdata, FE_DATA_W),
    `IOB_OUTPUT(ack, 1),

    // Cache invalidate and write-trough buffer IO chain
    `IOB_INPUT(invalidate_in, 1),
    `IOB_OUTPUT(invalidate_out, 1),
    `IOB_INPUT(wtb_empty_in, 1),
    `IOB_OUTPUT(wtb_empty_out, 1),

    // Back-end interface (AXI4 master)
`include "axi_m_port.vh"
`include "gen_if.vh"
    );

   //BLOCK Front-end & Front-end interface.
   wire                                         data_req, data_ack;
   wire [FE_ADDR_W -1:FE_NBYTES_W]              data_addr;
   wire [FE_DATA_W-1 : 0]                       data_wdata, data_rdata;
   wire [FE_NBYTES-1: 0]                        data_wstrb;
   wire [FE_ADDR_W -1:FE_NBYTES_W]              data_addr_reg;
   wire [FE_DATA_W-1 : 0]                       data_wdata_reg;
   wire [FE_NBYTES-1: 0]                        data_wstrb_reg;
   wire                                         data_req_reg;

   wire                                         ctrl_req, ctrl_ack;
   wire [`CTRL_ADDR_W-1:0]                      ctrl_addr;
   wire [CTRL_CACHE*(FE_DATA_W-1):0]            ctrl_rdata;
   wire                                         ctrl_invalidate;

   wire                                         wtbuf_full, wtbuf_empty;

   assign invalidate_out = ctrl_invalidate | invalidate_in;
   assign wtb_empty_out = wtbuf_empty & wtb_empty_in;

   iob_cache_front_end
     #(
       .ADDR_W (FE_ADDR_W-FE_NBYTES_W),
       .DATA_W (FE_DATA_W),
       .CTRL_CACHE(CTRL_CACHE)
       )
   front_end
     (
      .clk   (clk),
      .reset (rst),

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

   //BLOCK Cache memory & This block implements the cache memory.
   wire                                         write_hit, write_miss, read_hit, read_miss;

   // back-end write-channel
   wire                                         write_req, write_ack;
   wire [FE_ADDR_W-1:FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr;
   wire [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 :0] write_wdata;
   wire [FE_NBYTES-1:0]                                                       write_wstrb;

   // back-end read-channel
   wire                                                                       replace_req, replace;
   wire [FE_ADDR_W -1:BE_NBYTES_W+LINE2BE_W]                                  replace_addr;
   wire                                                                       read_req;
   wire [LINE2BE_W-1:0]                                                       read_addr;
   wire [BE_DATA_W-1:0]                                                       read_rdata;

   iob_cache_memory
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),
       .BE_DATA_W (BE_DATA_W),
       .NWAYS_W (NWAYS_W),
       .NLINES_W (NLINES_W),
       .WORD_OFFSET_W (WORD_OFFSET_W),
       .REP_POLICY (REP_POLICY),
       .WTBUF_DEPTH_W (WTBUF_DEPTH_W),
       .CTRL_CACHE(CTRL_CACHE),
       .CTRL_CNT (CTRL_CNT),
       .WRITE_POL (WRITE_POL)
       )
   cache_memory
     (
      .clk   (clk),
      .reset (rst),

      // front-end
      .req (data_req),
      .addr (data_addr[FE_ADDR_W-1 : BE_NBYTES_W+LINE2BE_W]),
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

   //BLOCK Back-end interface & This block interfaces with the system level or next-level cache.
   iob_cache_back_end_axi
     #(
       .FE_ADDR_W (FE_ADDR_W),
       .FE_DATA_W (FE_DATA_W),
       .BE_ADDR_W (BE_ADDR_W),
       .BE_DATA_W (BE_DATA_W),
       .WORD_OFFSET_W(WORD_OFFSET_W),
       .WRITE_POL (WRITE_POL),
       .AXI_ID_W(AXI_ID_W),
       .AXI_ID(AXI_ID)
       )
   back_end
     (
      .clk(clk),
      .reset(rst),

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

      // back-end read-channel
      // read address
      .axi_arvalid (axi_arvalid),
      .axi_araddr (axi_araddr),
      .axi_arlen (axi_arlen),
      .axi_arsize (axi_arsize),
      .axi_arburst (axi_arburst),
      .axi_arlock (axi_arlock),
      .axi_arcache (axi_arcache),
      .axi_arprot (axi_arprot),
      .axi_arqos (axi_arqos),
      .axi_arid (axi_arid),
      .axi_arready (axi_arready),

      // read data
      .axi_rvalid (axi_rvalid),
      .axi_rdata (axi_rdata),
      .axi_rresp (axi_rresp),
      .axi_rlast (axi_rlast),
      .axi_rready (axi_rready),

      // back-end write-channel
      // write address
      .axi_awvalid (axi_awvalid),
      .axi_awaddr (axi_awaddr),
      .axi_awlen (axi_awlen),
      .axi_awsize (axi_awsize),
      .axi_awburst (axi_awburst),
      .axi_awlock (axi_awlock),
      .axi_awcache (axi_awcache),
      .axi_awprot (axi_awprot),
      .axi_awqos (axi_awqos),
      .axi_awid (axi_awid),
      .axi_awready (axi_awready),

      // write data
      .axi_wvalid (axi_wvalid),
      .axi_wdata (axi_wdata),
      .axi_wstrb (axi_wstrb),
      .axi_wready (axi_wready),
      .axi_wlast (axi_wlast),

      // write response
      .axi_bvalid (axi_bvalid),
      .axi_bresp (axi_bresp),
      .axi_bready (axi_bready)
      );

   //BLOCK Cache control & Cache control block.
   generate
      if (CTRL_CACHE)
        iob_cache_control
          #(
            .FE_DATA_W  (FE_DATA_W),
            .CTRL_CNT   (CTRL_CNT)
            )
        cache_control
          (
           .clk   (clk),
           .reset (rst),

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
