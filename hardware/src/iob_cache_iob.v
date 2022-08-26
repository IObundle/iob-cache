`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "iob_cache.vh"
`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_iob
  #(
    parameter ADDR_W = `IOB_CACHE_ADDR_W, //PARAM &  NS & 64 & Front-end address width (log2): defines the total memory space accessible via the cache, which must be a power of two.
    parameter DATA_W = `IOB_CACHE_DATA_W, //PARAM & 32 & 64 & Front-end data width (log2): this parameter allows supporting processing elements with various data widths.
    parameter BE_ADDR_W = `IOB_CACHE_BE_ADDR_W, //PARAM & NS  & NS & Back-end address width (log2): the value of this parameter must be equal or greater than ADDR_W to match the width of the back-end interface, but the address space is still dictated by ADDR_W.
    parameter BE_DATA_W = `IOB_CACHE_BE_DATA_W, //PARAM & 32 & 256 & Back-end data width (log2): the value of this parameter must be an integer  multiple $k \geq 1$ of DATA_W. If $k>1$, the memory controller can operate at a frequency higher than the cache's frequency. Typically, the memory controller has an asynchronous FIFO interface, so that it can sequentially process multiple commands received in paralell from the cache's back-end interface. 
    parameter NWAYS_W = `IOB_CACHE_NWAYS_W, //PARAM & 0 & 8 & Number of cache ways (log2): the miminum is 0 for a directly mapped cache; the default is 1 for a two-way cache; the maximum is limited by the desired maximum operating frequency, which degrades with the number of ways. 
    parameter NLINES_W = `IOB_CACHE_NLINES_W, //PARAM & NS & NS & Line offset width (log2): the value of this parameter equals the number of cache lines, given by 2**NLINES_W.
    parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W, //PARAM & 0 & NS & Word offset width (log2):  the value of this parameter equals the number of words per line, which is 2**OFFSET_W. 
    parameter WTBUF_DEPTH_W = `IOB_CACHE_WTBUF_DEPTH_W, //PARAM & NS & NS & Write-through buffer depth (log2). A shallow buffer will fill up more frequently and cause write stalls; however, on a Read After Write (RAW) event, a shallow buffer will empty faster, decreasing the duration of the read stall. A deep buffer is unlkely to get full and cause write stalls; on the other hand, on a RAW event, it will take a long time to empty and cause long read stalls.
    parameter REP_POLICY = `IOB_CACHE_REP_POLICY, //PARAM & 0 & 3 & Line replacement policy: set to 0 for Least Recently Used (LRU); set to 1 for Pseudo LRU based on Most Recently Used (PLRU_MRU); set to 2 for tree-based Pseudo LRU (PLRU_TREE).
    parameter WRITE_POL = `IOB_CACHE_WRITE_THROUGH, //PARAM & 0 & 1 & Write policy: set to 0 for write-through or set to 1 for write-back.
    parameter USE_CTRL = `IOB_CACHE_USE_CTRL, //PARAM & 0 & 1 & Instantiates a cache controller (1) or not (0). The cache controller provides memory-mapped software accessible registers to invalidate the cache data contents, and monitor the write through buffer status using the front-end interface. To access the cache controller, the MSB of the address mut be set to 1. For more information refer to the example software functions provided.
    parameter USE_CTRL_CNT = `IOB_CACHE_USE_CTRL_CNT //PARAM & 0 & 1 & Instantiates hit/miss counters for reads, writes or both (1), or not (0). This parameter is meaningful if the cache controller is present (USE_CTRL=1), providing additional software accessible functions for these functions.
    )
   (
    // Front-end interface (IOb native slave)
    //START_IO_TABLE fe
    `IOB_INPUT(req, 1), //Read or write request from host. If signal {\tt ack} raises in the next cyle the request has been served; otherwise {\tt req} should remain high until {\tt ack} raises. When {\tt ack} raises in response to a previous request, {\tt req} may keep high, or combinatorially lowered in the same cycle. If {\tt req} keeps high, a new request is being made to the current address {\tt addr}; if {\tt req} lowers, no new request is being made. Note that the new request is being made in parallel with acknowledging the previous request: pipelined operation.
    `IOB_INPUT(addr, USE_CTRL+ADDR_W-`IOB_CACHE_NBYTES_W), //Address from CPU or other user core, excluding the byte selection LSBs.
    `IOB_INPUT(wdata, DATA_W), //Write data fom host.
    `IOB_INPUT(wstrb, `IOB_CACHE_NBYTES), //Byte write strobe from host.
    `IOB_OUTPUT(rdata, DATA_W), //Read data to host.
    `IOB_OUTPUT(ack,1), //Acknowledge signal from cache: indicates that the last request has been served. The next request can be issued as soon as this signal raises, in the same clock cycle, or later after it becomes low.

    // Back-end interface
    //START_IO_TABLE be
    `IOB_OUTPUT(be_req, 1), //Read or write request to next-level cache or memory.
    `IOB_OUTPUT(be_addr, BE_ADDR_W),  //Address to next-level cache or memory.
    `IOB_OUTPUT(be_wdata, BE_DATA_W), //Write data to next-level cache or memory.
    `IOB_OUTPUT(be_wstrb, `IOB_CACHE_BE_NBYTES), //Write strobe to next-level cache or memory.
    `IOB_INPUT(be_rdata, BE_DATA_W),  //Read data from next-level cache or memory.
    `IOB_INPUT(be_ack, 1), //Acknowledge signal from next-level cache or memory.

    // Cache invalidate and write-trough buffer IO chain
    //START_IO_TABLE ie
    `IOB_INPUT(invalidate_in,1), //Invalidates all cache lines instantaneously if high.
    `IOB_OUTPUT(invalidate_out,1), //This output is asserted high when the cache is invalidated via the cache controller or the direct {\tt invalidate_in} signal. The present {\tt invalidate_out} signal is useful for invalidating the next-level cache if there is one. If not, this output should be floated.
    `IOB_INPUT(wtb_empty_in,1), //This input is driven by the next-level cache, if there is one, when its write-through buffer is empty. It should be tied high if there is no next-level cache. This signal is used to compute the overall empty status of a cache hierarchy, as explained for signal {\tt wtb_empty_out}.
    `IOB_OUTPUT(wtb_empty_out,1), //This output is high if the cache's write-through buffer is empty and its {\tt wtb_empty_in} signal is high. This signal informs that all data written to the cache has been written to the destination memory module, and all caches on the way are empty.
    
    //General Interface Signals
    `include "iob_gen_if.vh"
    );

   //BLOCK Front-end & This NIP interface is connected to a processor or any other processing element that needs a cache buffer to improve the performance of accessing a slower but larger memory.
   wire                              data_req, data_ack;
   wire [ADDR_W -1:`IOB_CACHE_NBYTES_W]        data_addr;
   wire [DATA_W-1 : 0]               data_wdata, data_rdata;
   wire [`IOB_CACHE_NBYTES-1: 0]               data_wstrb;
   wire [ADDR_W -1:`IOB_CACHE_NBYTES_W]        data_addr_reg;
   wire [DATA_W-1 : 0]               data_wdata_reg;
   wire [`IOB_CACHE_NBYTES-1: 0]               data_wstrb_reg;
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
       .ADDR_W (ADDR_W-`IOB_CACHE_NBYTES_W),
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

   //BLOCK Cache memory & This block contains the tag, data storage memories and the Write Through Buffer if the correspeonding write policy is selected; these memories are implemented either with RAM if large enough, or with registers if small enough.
   wire                              write_hit, write_miss, read_hit, read_miss;

   // back-end write-channel
   wire                              write_req, write_ack;
   wire [ADDR_W-1:`IOB_CACHE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr;
   wire [DATA_W + WRITE_POL*(DATA_W*(2**WORD_OFFSET_W)-DATA_W)-1 :0] write_wdata;
   wire [`IOB_CACHE_NBYTES-1:0]                                                write_wstrb;

   // back-end read-channel
   wire                                                              replace_req, replace;
   wire [ADDR_W -1:`IOB_CACHE_BE_NBYTES_W+`IOB_CACHE_LINE2BE_W]                          replace_addr;
   wire                                                              read_req;
   wire [`IOB_CACHE_LINE2BE_W-1:0]                                             read_addr;
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
      .addr      (data_addr[ADDR_W-1 : `IOB_CACHE_BE_NBYTES_W+`IOB_CACHE_LINE2BE_W]),
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

   //BLOCK Cache control & Cache controller: this block is used for invalidating the cache, monitoring the status of the Write Thorough buffer, and accessing read/write hit/miss counters.
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
