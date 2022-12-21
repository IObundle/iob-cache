`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "iob_cache.vh"
`include "iob_cache_conf.vh"

module iob_cache
  #(
`ifdef AXI
    parameter AXI_ID_W = `IOB_CACHE_AXI_ID_W,
    parameter AXI_LEN_W = `IOB_CACHE_AXI_LEN_W,
    parameter AXI_ADDR_W = BE_ADDR_W,
    parameter AXI_DATA_W = BE_DATA_W,
    parameter [AXI_ID_W-1:0] AXI_ID = `IOB_CACHE_AXI_ID,
`endif
    parameter FE_ADDR_W = `IOB_CACHE_FE_ADDR_W, //PARAM &   & 64 & Front-end address width (log2): defines the total memory space accessible via the cache, which must be a power of two.
    parameter FE_DATA_W = `IOB_CACHE_FE_DATA_W, //PARAM & 32 & 64 & Front-end data width (log2): this parameter allows supporting processing elements with various data widths.
    parameter BE_ADDR_W = `IOB_CACHE_BE_ADDR_W, //PARAM &   &  & Back-end address width (log2): the value of this parameter must be equal or greater than ADDR_W to match the width of the back-end interface, but the address space is still dictated by ADDR_W.
    parameter BE_DATA_W = `IOB_CACHE_BE_DATA_W, //PARAM & 32 & 256 & Back-end data width (log2): the value of this parameter must be an integer  multiple $k \geq 1$ of DATA_W. If $k>1$, the memory controller can operate at a frequency higher than the cache's frequency. Typically, the memory controller has an asynchronous FIFO interface, so that it can sequentially process multiple commands received in paralell from the cache's back-end interface. 
    parameter NWAYS_W = `IOB_CACHE_NWAYS_W, //PARAM & 0 & 8 & Number of cache ways (log2): the miminum is 0 for a directly mapped cache; the default is 1 for a two-way cache; the maximum is limited by the desired maximum operating frequency, which degrades with the number of ways. 
    parameter NLINES_W = `IOB_CACHE_NLINES_W, //PARAM &  &  & Line offset width (log2): the value of this parameter equals the number of cache lines, given by 2**NLINES_W.
    parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W, //PARAM & 0 &  & Word offset width (log2):  the value of this parameter equals the number of words per line, which is 2**OFFSET_W. 
    parameter WTBUF_DEPTH_W = `IOB_CACHE_WTBUF_DEPTH_W, //PARAM &  &  & Write-through buffer depth (log2). A shallow buffer will fill up more frequently and cause write stalls; however, on a Read After Write (RAW) event, a shallow buffer will empty faster, decreasing the duration of the read stall. A deep buffer is unlkely to get full and cause write stalls; on the other hand, on a RAW event, it will take a long time to empty and cause long read stalls.
    parameter REP_POLICY = `IOB_CACHE_REP_POLICY, //PARAM & 0 & 3 & Line replacement policy: set to 0 for Least Recently Used (LRU); set to 1 for Pseudo LRU based on Most Recently Used (PLRU_MRU); set to 2 for tree-based Pseudo LRU (PLRU_TREE).
    parameter WRITE_POL = `IOB_CACHE_WRITE_THROUGH, //PARAM & 0 & 1 & Write policy: set to 0 for write-through or set to 1 for write-back.
    parameter USE_CTRL = `IOB_CACHE_USE_CTRL, //PARAM & 0 & 1 & Instantiates a cache controller (1) or not (0). The cache controller provides memory-mapped software accessible registers to invalidate the cache data contents, and monitor the write through buffer status using the front-end interface. To access the cache controller, the MSB of the address mut be set to 1. For more information refer to the example software functions provided.
    parameter USE_CTRL_CNT = `IOB_CACHE_USE_CTRL_CNT //PARAM & 0 & 1 & Instantiates hit/miss counters for reads, writes or both (1), or not (0). This parameter is meaningful if the cache controller is present (USE_CTRL=1), providing additional software accessible functions for these functions.
    )
   (
    // Front-end interface (IOb native slave)
    //START_IO_TABLE fe
    `IOB_INPUT(req, 1), //V2TEX_IO Read or write request from host. If signal {\tt ack} raises in the next cyle the request has been served; otherwise {\tt req} should remain high until {\tt ack} raises. When {\tt ack} raises in response to a previous request, {\tt req} may keep high, or combinatorially lowered in the same cycle. If {\tt req} keeps high, a new request is being made to the current address {\tt addr}; if {\tt req} lowers, no new request is being made. Note that the new request is being made in parallel with acknowledging the previous request: pipelined operation.
    `IOB_INPUT(addr, USE_CTRL+FE_ADDR_W-`IOB_CACHE_NBYTES_W), //V2TEX_IO Address from CPU or other user core, excluding the byte selection LSBs.
    `IOB_INPUT(wdata, FE_DATA_W), //V2TEX_IO Write data fom host.
    `IOB_INPUT(wstrb, `IOB_CACHE_NBYTES), //V2TEX_IO Byte write strobe from host.
    `IOB_OUTPUT(rdata, FE_DATA_W), //V2TEX_IO Read data to host.
    `IOB_OUTPUT(ack,1), //V2TEX_IO Acknowledge signal from cache: indicates that the last request has been served. The next request can be issued as soon as this signal raises, in the same clock cycle, or later after it becomes low.

    // Back-end interface
`ifdef AXI
 `include "axi_m_port.vh"
`else
    //START_IO_TABLE be
    `IOB_OUTPUT(be_req, 1), //V2TEX_IO Read or write request to next-level cache or memory.
    `IOB_OUTPUT(be_addr, BE_ADDR_W),  //V2TEX_IO Address to next-level cache or memory.
    `IOB_OUTPUT(be_wdata, BE_DATA_W), //V2TEX_IO Write data to next-level cache or memory.
    `IOB_OUTPUT(be_wstrb, `IOB_CACHE_BE_NBYTES), //V2TEX_IO Write strobe to next-level cache or memory.
    `IOB_INPUT(be_rdata, BE_DATA_W),  //V2TEX_IO Read data from next-level cache or memory.
    `IOB_INPUT(be_ack, 1), //V2TEX_IO Acknowledge signal from next-level cache or memory.
`endif
    // Cache invalidate and write-trough buffer IO chain
    //START_IO_TABLE ie
    `IOB_INPUT(invalidate_in,1), //V2TEX_IO Invalidates all cache lines instantaneously if high.
    `IOB_OUTPUT(invalidate_out,1), //V2TEX_IO This output is asserted high when the cache is invalidated via the cache controller or the direct {\tt invalidate_in} signal. The present {\tt invalidate_out} signal is useful for invalidating the next-level cache if there is one. If not, this output should be floated.
    `IOB_INPUT(wtb_empty_in,1), //V2TEX_IO This input is driven by the next-level cache, if there is one, when its write-through buffer is empty. It should be tied high if there is no next-level cache. This signal is used to compute the overall empty status of a cache hierarchy, as explained for signal {\tt wtb_empty_out}.
    `IOB_OUTPUT(wtb_empty_out,1), //V2TEX_IO This output is high if the cache's write-through buffer is empty and its {\tt wtb_empty_in} signal is high. This signal informs that all data written to the cache has been written to the destination memory module, and all caches on the way are empty.
   //General Interface Signals
   `IOB_INPUT(clk_i,         1), //V2TEX_IO System clock input.
   `IOB_INPUT(rst_i,         1)  //V2TEX_IO System reset, asynchronous and active high.
   );	

`ifdef AXI   
   iob_cache_axi
`else
     iob_cache_iob
`endif     
       #(
         .FE_ADDR_W(FE_ADDR_W),
         .FE_DATA_W(FE_DATA_W),
         .BE_ADDR_W(BE_ADDR_W),
         .BE_DATA_W(BE_DATA_W),
         .NWAYS_W(NWAYS_W),
         .NLINES_W(NLINES_W),
         .WORD_OFFSET_W(WORD_OFFSET_W),
         .WTBUF_DEPTH_W(WTBUF_DEPTH_W),
         .WRITE_POL(WRITE_POL),
         .REP_POLICY(REP_POLICY),
         .USE_CTRL(USE_CTRL)
         )
`ifdef AXI   
   cache_axi
`else
     cache_iob
`endif     
       (
        //front-end
        .wdata (wdata),
        .addr  (addr),
        .wstrb (wstrb),
        .rdata (rdata),
        .req (req),
        .ack (ack),

        //invalidate / wtb empty
        .invalidate_in(1'b0),
        .invalidate_out(),
        .wtb_empty_in(1'b1),
        .wtb_empty_out(),

        //back-end
`ifdef AXI
 `include "axi_m_m_portmap.vh"
`else
        .be_addr(be_addr),
        .be_wdata(be_wdata),
        .be_wstrb(be_wstrb),
        .be_rdata(be_rdata),
        .be_req(be_req),
        .be_ack(be_ack),
`endif
        .clk_i (clk_i),
        .rst_i (rst_i)
        );

endmodule
