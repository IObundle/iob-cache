`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "iob_cache.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_iob
  #(
    parameter ADDR_W = `ADDR_W, //PARAM &  NS & 64 & Front-end address width (log2): defines the total memory space accessible via the cache, which must be a power of two.
    parameter DATA_W = `DATA_W, //PARAM & 32 & 64 & Front-end data width (log2): this parameter allows supporting processing elements with various data widths.
    parameter BE_ADDR_W = `BE_ADDR_W, //PARAM & NS  & NS & Back-end address width (log2): the value of this parameter must be equal or greater than ADDR_W to match the width of the back-end interface, but the address space is still dictated by ADDR_W.
    parameter BE_DATA_W = `BE_DATA_W, //PARAM & 32 & 256 & Back-end data width (log2): the value of this parameter must be an integer  multiple $k \geq 1$ of DATA_W. If $k>1$, the memory controller can operate at a frequency higher than the cache's frequency. Typically, the memory controller has an asynchronous FIFO interface, so that it can sequentially process multiple commands received in paralell from the cache's back-end interface. 
    parameter NWAYS_W = `NWAYS_W, //PARAM & 0 & 8 & Number of cache ways (log2): the miminum is 0 for a directly mapped cache; the default is a two-way cache; the maximum is limited by the desired maximum operating frequency, which degrades with the number of ways. 
    parameter NLINES_W = `NLINES_W, //PARAM & NS & NS & Line offset width (log2): the value of this parameter equals the number of cache lines, which is 2**NLINES_W.
    parameter WORD_OFFSET_W = `WORD_OFFSET_W, //PARAM & 0 & NS & Word offset width (log2):  the value of this parameter equals the number of words per line, which is 2**OFFSET_W. 
    parameter WTBUF_DEPTH_W = `WTBUF_DEPTH_W, //PARAM & NS & NS & Write-through buffer depth (log2). A shallow buffer increases the likelyhood of filling up the buffer and getting write stalls; however, on a Read After Write (RAW) event, a shallow buffer will empty much faster. A deep buffer is unlkely to get full and cause write stalls; on the other hand, on a RAW event, it will take a long time to empty its contents to the back-end interface.
    parameter REP_POLICY = `REP_POLICY, //PARAM & 0 & 3 & Line replacement policy: set to 0 for Least Recently Used (LRU); set to 1 for Pseudo LRU based on Most Recently Used (PLRU_MRU); set to 2 for Tree-based Pseudo LRU (PLRU_TREE).
    parameter WRITE_POL = `WRITE_THROUGH, //PARAM & 0 & 1 & Write policy: set to 0 for write-through or set to 1 for write-back.
    parameter USE_CTRL = `USE_CTRL, //PARAM & 0 & 1 & Instantiates a cache controller (1) or not (0). If the controller is present, all cache lines can be invalidated, and the write through buffer status can be read.
    parameter USE_CTRL_CNT = `USE_CTRL_CNT //PARAM & 0 & 1 & If the cache controller is present (USE_CTRL=1) and this parameter is set to 1, the cache includes hit/miss counters for reads, writes or both, available through the front-end interface.
    )
   (
    // Front-end interface (IOb native slave)
    //START_IO_TABLE fe
    `IOB_INPUT(req, 1), //Read or write request from CPU or other user core. If {\tt ack} becomes high in the next cyle the request has been served; otherwise {\tt req} should remain high until {\tt ack} returns to high. When {\tt ack} becomes high in reponse to a previous request, {\tt req} may be lowered in the same cycle ack becomes high if there are no more requests to make. The next request can be made while {\tt ack} is high in reponse to the previous request
    `IOB_INPUT(addr, USE_CTRL+ADDR_W-`NBYTES_W), //Address from CPU or other user core, excluding the byte selection LSBs.
    `IOB_INPUT(wdata, DATA_W), //Write data fom host.
    `IOB_INPUT(wstrb, `NBYTES), //Byte write strobe.
    `IOB_OUTPUT(rdata, DATA_W), //Read data to host.
    `IOB_OUTPUT(ack,1), //Acknowledges that the last request has been served; the next request can be issued when this signal is high or when this signla is low but has already pulsed high in response to the last request.

    // Back-end interface
    //START_IO_TABLE be
    `IOB_OUTPUT(be_req, 1), //Read or write request to next-level cache or memory. If {\tt be_ack} becomes high in the next cyle the request has been served; otherwise {\tt be_req} should remain high until {\tt be_ack} returns to high. When {\tt ack} becomes high in reponse to a previous request, {\tt be_req} may be lowered in the same cycle ack becomes high if there are no more requests to make. The next request can be made while {\tt be_ack} is high in reponse to the previous request.
    `IOB_OUTPUT(be_addr, BE_ADDR_W),  //Address to next-level cache or memory
    `IOB_OUTPUT(be_wdata, BE_DATA_W), //Write data to next-level cache or memory
    `IOB_OUTPUT(be_wstrb, `BE_NBYTES), //Write strobe to next-level cache or memory
    `IOB_INPUT(be_rdata, BE_DATA_W),  //Read data to host.
    `IOB_INPUT(be_ack, 1), //Acknowledges that the last request has been served; the next request can be issued when this signal is high or when this signal is low but has already pulsed high in reponse to the last request.

    // Cache invalidate and write-trough buffer IO chain
    //START_IO_TABLE ie
    `IOB_INPUT(invalidate_in,1), //Invalidates all cache lines if high.
    `IOB_OUTPUT(invalidate_out,1), //This output is asserted high whenever the cache is invalidated.
    `IOB_INPUT(wtb_empty_in,1), //This input may be driven the next-level cache, when its write-through buffer is empty. It should be tied to high if there no next-level cache.
    `IOB_OUTPUT(wtb_empty_out,1), //This output is high if the cache's write-through buffer is empty and the {\tt wtb_empty_in} signal is high.
    
    //General Interface Signals
    `include "iob_gen_if.vh"
    );

   //BLOCK Front-end & This NIP interface is connected to a processor or any other processing element that needs a cache buffer to improve the performance of accessing a slower but bigger memory.
   wire                              data_req, data_ack;
   wire [ADDR_W -1:`NBYTES_W]        data_addr;
   wire [DATA_W-1 : 0]               data_wdata, data_rdata;
   wire [`NBYTES-1: 0]               data_wstrb;
   wire [ADDR_W -1:`NBYTES_W]        data_addr_reg;
   wire [DATA_W-1 : 0]               data_wdata_reg;
   wire [`NBYTES-1: 0]               data_wstrb_reg;
   wire                              data_req_reg;

   wire                              ctrl_req, ctrl_ack;
   wire [`iob_cache_swreg_ADDR_W-1:0]           ctrl_addr;
   wire [USE_CTRL*(DATA_W-1):0]      ctrl_rdata;
   wire                              ctrl_invalidate;

   wire                              wtbuf_full, wtbuf_empty;

   assign invalidate_out = ctrl_invalidate | invalidate_in;
   assign wtb_empty_out  = wtbuf_empty & wtb_empty_in;

   iob_cache_front_end
     #(
       .ADDR_W (ADDR_W-`NBYTES_W),
       .DATA_W (DATA_W),
       .USE_CTRL(USE_CTRL)
       )
   front_end
     (
      .clk(clk),
      .reset(rst),
      
      // front-end port
      .req   (req),
      .addr  (addr),
      .wdata (wdata),
      .wstrb (wstrb),
      .rdata (rdata),
      .ack   (ack),

      // cache-memory input signals
      .data_req  (data_req),
      .data_addr (data_addr),

      // cache-memory output
      .data_rdata (data_rdata),
      .data_ack   (data_ack),

      // stored input signals
      .data_req_reg   (data_req_reg),
      .data_addr_reg  (data_addr_reg),
      .data_wdata_reg (data_wdata_reg),
      .data_wstrb_reg (data_wstrb_reg),

      // cache-controller
      .ctrl_req   (ctrl_req),
      .ctrl_addr  (ctrl_addr),
      .ctrl_rdata (ctrl_rdata),
      .ctrl_ack   (ctrl_ack)
      );

   //BLOCK Cache memory & Cache tag and data storage memories; these memories are implemented either with RAM if large enough, or with registers if small enough.
   wire                              write_hit, write_miss, read_hit, read_miss;

   // back-end write-channel
   wire                              write_req, write_ack;
   wire [ADDR_W-1:`NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr;
   wire [DATA_W + WRITE_POL*(DATA_W*(2**WORD_OFFSET_W)-DATA_W)-1 :0] write_wdata;
   wire [`NBYTES-1:0]                                                write_wstrb;

   // back-end read-channel
   wire                                                              replace_req, replace;
   wire [ADDR_W -1:`BE_NBYTES_W+`LINE2BE_W]                          replace_addr;
   wire                                                              read_req;
   wire [`LINE2BE_W-1:0]                                             read_addr;
   wire [BE_DATA_W-1:0]                                              read_rdata;

   iob_cache_memory
     #(
       .ADDR_W (ADDR_W),
       .DATA_W (DATA_W),
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
      .clk   (clk),
      .reset (rst),

      // front-end
      .req       (data_req),
      .addr      (data_addr[ADDR_W-1 : `BE_NBYTES_W+`LINE2BE_W]),
      .rdata     (data_rdata),
      .ack       (data_ack),
      .req_reg   (data_req_reg),
      .addr_reg  (data_addr_reg),
      .wdata_reg (data_wdata_reg),
      .wstrb_reg (data_wstrb_reg),

      // back-end
      // write-through-buffer (write-channel)
      .write_req   (write_req),
      .write_addr  (write_addr),
      .write_wdata (write_wdata),
      .write_wstrb (write_wstrb),
      .write_ack   (write_ack),

      // cache-line replacement (read-channel)
      .replace_req  (replace_req),
      .replace_addr (replace_addr),
      .replace      (replace),
      .read_req     (read_req),
      .read_addr    (read_addr),
      .read_rdata   (read_rdata),

      // control's signals
      .wtbuf_empty (wtbuf_empty),
      .wtbuf_full  (wtbuf_full),
      .write_hit   (write_hit),
      .write_miss  (write_miss),
      .read_hit    (read_hit),
      .read_miss   (read_miss),
      .invalidate  (invalidate_out)
      );

   //BLOCK Back-end interface & Memory-side interface: if the cache is at the last level before the target memory module, the back-end interface connects to the target memory (e.g. DDR) controller; if the cache is not at the last level, the back-end interface connects to the next-level cache. This interface can be of type NPI or AXI4 as per configuration. If it is connected to the next-level IOb-Cache, the NPI type must be selected; if it is connected to a third party cache or memory controlller featuring an AXI4 interface, then the AXI4 type must be selected.
   iob_cache_back_end
     #(
       .ADDR_W (ADDR_W),
       .DATA_W (DATA_W),
       .BE_DATA_W (BE_DATA_W),
       .WORD_OFFSET_W (WORD_OFFSET_W),
       .WRITE_POL (WRITE_POL)
       )
   back_end
     (
      .clk   (clk),
      .reset (rst),

      // write-through-buffer (write-channel)
      .write_valid (write_req),
      .write_addr  (write_addr),
      .write_wdata (write_wdata),
      .write_wstrb (write_wstrb),
      .write_ready (write_ack),

      // cache-line replacement (read-channel)
      .replace_valid (replace_req),
      .replace_addr  (replace_addr),
      .replace       (replace),
      .read_valid    (read_req),
      .read_addr     (read_addr),
      .read_rdata    (read_rdata),

      // back-end native interface
      .be_valid (be_req),
      .be_addr  (be_addr),
      .be_wdata (be_wdata),
      .be_wstrb (be_wstrb),
      .be_rdata (be_rdata),
      .be_ready (be_ack)
      );

   //BLOCK Cache control & Cache controller: this block is used for invalidating the cache, monitoring the status of the Write Thorough buffer, accessing hit/miss counters, etc.
   generate
      if (USE_CTRL)
        iob_cache_control
          #(
            .DATA_W (DATA_W),
            .USE_CTRL_CNT  (USE_CTRL_CNT)
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
