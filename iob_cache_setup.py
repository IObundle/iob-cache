#!/usr/bin/env python3

import os, sys
sys.path.insert(0, os.getcwd()+'/submodules/LIB/scripts')
import setup

meta = \
{
'name':'iob_cache',
'version':'V0.10',
'flows':'sim doc fpga',
'setup_dir':os.path.dirname(__file__)}
meta['build_dir']=f"../{meta['name']+'_'+meta['version']}"
meta['submodules'] = {
    'hw_setup': {
        'headers' : [ 'iob_s_port', 'axi_m_port', 'axi_m_m_portmap', 'axi_m_write_port', 'axi_m_m_write_portmap', 'axi_m_read_port', 'axi_m_m_read_portmap'  ],
        'modules': [ 'iob_regfile_sp.v', 'iob_fifo_sync', 'iob_ram_2p.v', 'iob_ram_sp.v', 'iob_wstrb2byte_offset.v', 'iob_reg.v' ]
    },
    'sim_setup': {
        'headers' : [ 'axi_portmap', 'axi_wire', 'axi_m_portmap' ],
        'modules': [ 'iob_ram_sp_be.v', 'axi_ram.v' ]
    },
    'sw_setup': {
        'headers': [  ],
        'modules': [  ]
    },
    'dirs': {
        'LIB':f"{meta['setup_dir']}/submodules/LIB",
    }
}

confs = \
[
    # Macros
    #Replacement Policy
    {'name':'LRU', 'type':'M', 'val':'0', 'min':'?', 'max':'?', 'descr':'Least Recently Used -- more resources intensive - N*log2(N) bits per cache line - Uses counters'},
    {'name':'PLRU_MRU', 'type':'M', 'val':'1', 'min':'?', 'max':'?', 'descr':'bit-based Pseudo-Least-Recently-Used, a simpler replacement policy than LRU, using a much lower complexity (lower resources) - N bits per cache line'},
    {'name':'PLRU_TREE', 'type':'M', 'val':'2', 'min':'?', 'max':'?', 'descr':'tree-based Pseudo-Least-Recently-Used, uses a tree that updates after any way received an hit, and points towards the oposing one. Uses less resources than bit-pseudo-lru - N-1 bits per cache line'},
    #Write Policy
    {'name':'WRITE_THROUGH', 'type':'M', 'val':'0', 'min':'?', 'max':'?', 'descr':'write-through not allocate: implements a write-through buffer'},
    {'name':'WRITE_BACK', 'type':'M', 'val':'1', 'min':'?', 'max':'?', 'descr':'write-back allocate: implementes a dirty-memory'},
    #AXI4
    {'name':'AXI_ID_W', 'type':'M', 'val':'1', 'min':'?', 'max':'?', 'descr':'description'},
    {'name':'AXI_LEN_W', 'type':'M', 'val':'4', 'min':'?', 'max':'?', 'descr':'description'},
    {'name':'AXI_ID', 'type':'M', 'val':'0', 'min':'?', 'max':'?', 'descr':'description'},
    {'name':'AXI_ID_W', 'type':'M', 'val':'1', 'min':'?', 'max':'?', 'descr':'description'},
    # Required by iob_cache_control.v
    {'name':'VERSION', 'type':'M', 'val':'0010', 'min':'?', 'max':'?', 'descr':'description'},

    # Swreg_gen parameters
    {'name':'ADDR_W', 'type':'P', 'val':'`IOB_CACHE_SWREG_ADDR_W', 'min':'NA', 'max':'NA', 'descr':'Cache address width used by swreg_gen'},
    {'name':'DATA_W', 'type':'P', 'val':'`IOB_CACHE_FE_DATA_W', 'min':'NA', 'max':'NA', 'descr':'Cache data width used by swreg_gen'},
    #TODO: Need to handle ifdef AXI
    #{'name':'AXI_ID_W', 'type':'P', 'val':'`IOB_CACHE_AXI_ID_W', 'min':'1', 'max':'NA', 'descr':'AXI ID bus width'},
    #{'name':'AXI_LEN_W', 'type':'P', 'val':'`IOB_CACHE_AXI_LEN_W', 'min':'1', 'max':'NA', 'descr':'AXI LEN bus width'},
    #{'name':'AXI_ADDR_W', 'type':'P', 'val':'BE_ADDR_W', 'min':'1', 'max':'NA', 'descr':'AXI address bus width'},
    #{'name':'AXI_DATA_W', 'type':'P', 'val':'BE_DATA_W', 'min':'1', 'max':'NA', 'descr':'AXI data bus width'},
    #{'name':'[AXI_ID_W-1:0] AXI_ID', 'type':'P', 'val':'`IOB_CACHE_AXI_ID', 'min':'?', 'max':'NA', 'descr':'AXI ID bus'},
    # Other parameters
    {'name':'FE_ADDR_W', 'type':'P', 'val':'24', 'min':'1', 'max':'64', 'descr':'Front-end address width (log2): defines the total memory space accessible via the cache, which must be a power of two.'},
    {'name':'FE_DATA_W', 'type':'P', 'val':'32', 'min':'32', 'max':'64', 'descr':'Front-end data width (log2): this parameter allows supporting processing elements with various data widths.'},
    {'name':'BE_ADDR_W', 'type':'P', 'val':'24', 'min':'1', 'max':'', 'descr':'Back-end address width (log2): the value of this parameter must be equal or greater than FE_ADDR_W to match the width of the back-end interface, but the address space is still dictated by ADDR_W.'},
    {'name':'BE_DATA_W', 'type':'P', 'val':'32', 'min':'32', 'max':'256', 'descr':'Back-end data width (log2): the value of this parameter must be an integer  multiple $k \geq 1$ of DATA_W. If $k>1$, the memory controller can operate at a frequency higher than the cache\'s frequency. Typically, the memory controller has an asynchronous FIFO interface, so that it can sequentially process multiple commands received in paralell from the cache\'s back-end interface. '},
    {'name':'NWAYS_W', 'type':'P', 'val':'1', 'min':'0', 'max':'8', 'descr':'Number of cache ways (log2): the miminum is 0 for a directly mapped cache; the default is 1 for a two-way cache; the maximum is limited by the desired maximum operating frequency, which degrades with the number of ways. '},
    {'name':'NLINES_W', 'type':'P', 'val':'7', 'min':'', 'max':'', 'descr':'Line offset width (log2): the value of this parameter equals the number of cache lines, given by 2**NLINES_W.'},
    {'name':'WORD_OFFSET_W', 'type':'P', 'val':'3', 'min':'0', 'max':'', 'descr':'Word offset width (log2):  the value of this parameter equals the number of words per line, which is 2**OFFSET_W. '},
    {'name':'WTBUF_DEPTH_W', 'type':'P', 'val':'4', 'min':'', 'max':'', 'descr':'Write-through buffer depth (log2). A shallow buffer will fill up more frequently and cause write stalls; however, on a Read After Write (RAW) event, a shallow buffer will empty faster, decreasing the duration of the read stall. A deep buffer is unlkely to get full and cause write stalls; on the other hand, on a RAW event, it will take a long time to empty and cause long read stalls.'},
    {'name':'REP_POLICY', 'type':'P', 'val':'0', 'min':'0', 'max':'3', 'descr':'Line replacement policy: set to 0 for Least Recently Used (LRU); set to 1 for Pseudo LRU based on Most Recently Used (PLRU_MRU); set to 2 for tree-based Pseudo LRU (PLRU_TREE).'},
    {'name':'WRITE_POL', 'type':'P', 'val':'0 ', 'min':'0', 'max':'1', 'descr':'Write policy: set to 0 for write-through or set to 1 for write-back.'},
    {'name':'USE_CTRL', 'type':'P', 'val':'0', 'min':'0', 'max':'1', 'descr':'Instantiates a cache controller (1) or not (0). The cache controller provides memory-mapped software accessible registers to invalidate the cache data contents, and monitor the write through buffer status using the front-end interface. To access the cache controller, the MSB of the address mut be set to 1. For more information refer to the example software functions provided.'},
    {'name':'USE_CTRL_CNT', 'type':'P', 'val':'0', 'min':'0', 'max':'1', 'descr':'Instantiates hit/miss counters for reads, writes or both (1), or not (0). This parameter is meaningful if the cache controller is present (USE_CTRL=1), providing additional software accessible functions for these functions.'},
]

ios = \
[
    {'name': 'fe', 'descr':'Front-end interface (IOb native slave)', 'ports': [
        {'name':'req', 'type':'I', 'n_bits':'1', 'descr':'Read or write request from host. If signal {\\tt ack} raises in the next cyle the request has been served; otherwise {\\tt req} should remain high until {\\tt ack} raises. When {\\tt ack} raises in response to a previous request, {\\tt req} may keep high, or combinatorially lowered in the same cycle. If {\\tt req} keeps high, a new request is being made to the current address {\\tt addr}; if {\\tt req} lowers, no new request is being made. Note that the new request is being made in parallel with acknowledging the previous request: pipelined operation.'},
        {'name':'addr', 'type':'I', 'n_bits':'USE_CTRL+FE_ADDR_W-`IOB_CACHE_NBYTES_W', 'descr':'Address from CPU or other user core, excluding the byte selection LSBs.'},
        {'name':'wdata', 'type':'I', 'n_bits':'FE_DATA_W', 'descr':'Write data fom host.'},
        {'name':'wstrb', 'type':'I', 'n_bits':'`IOB_CACHE_NBYTES', 'descr':'Byte write strobe from host.'},
        {'name':'rdata', 'type':'O', 'n_bits':'FE_DATA_W', 'descr':'Read data to host.'},
        {'name':'ack', 'type':'O','n_bits':'1', 'descr':'Acknowledge signal from cache: indicates that the last request has been served. The next request can be issued as soon as this signal raises, in the same clock cycle, or later after it becomes low.'}
    ]},
    {'name': 'be', 'descr':'Back-end interface', 'ports': [
#`ifdef AXI #TODO: Need to handle ifdef AXI
         #`include "iob_cache_axi_m_port.vh"
#`else
        {'name':'', 'type':'O', 'n_bits':'1', 'descr':'Read or write request to next-level cache or memory.'},
        {'name':'be_addr', 'type':'O', 'n_bits':'BE_ADDR_W', 'descr':'Address to next-level cache or memory.'},
        {'name':'be_wdata', 'type':'O', 'n_bits':'BE_DATA_W', 'descr':'Write data to next-level cache or memory.'},
        {'name':'be_wstrb', 'type':'O', 'n_bits':'`IOB_CACHE_BE_NBYTES', 'descr':'Write strobe to next-level cache or memory.'},
        {'name':'be_rdata', 'type':'I', 'n_bits':'BE_DATA_W', 'descr':'Read data from next-level cache or memory.'},
        {'name':'be_ack', 'type':'I', 'n_bits':'1', 'descr':'Acknowledge signal from next-level cache or memory.'}
#`endif
    ]},
    {'name': 'ie', 'descr':'Cache invalidate and write-trough buffer IO chain', 'ports': [
        {'name':'invalidate_in', 'type':'I','n_bits':'1', 'descr':'Invalidates all cache lines instantaneously if high.'},
        {'name':'invalidate_out', 'type':'O','n_bits':'1', 'descr':'This output is asserted high when the cache is invalidated via the cache controller or the direct {\\tt invalidate_in} signal. The present {\\tt invalidate_out} signal is useful for invalidating the next-level cache if there is one. If not, this output should be floated.'},
        {'name':'wtb_empty_in', 'type':'I','n_bits':'1', 'descr':'This input is driven by the next-level cache, if there is one, when its write-through buffer is empty. It should be tied high if there is no next-level cache. This signal is used to compute the overall empty status of a cache hierarchy, as explained for signal {\\tt wtb_empty_out}.'},
        {'name':'wtb_empty_out', 'type':'O','n_bits':'1', 'descr':'This output is high if the cache\'s write-through buffer is empty and its {\tt wtb_empty_in} signal is high. This signal informs that all data written to the cache has been written to the destination memory module, and all caches on the way are empty.'},
    ]},
    {'name': 'ge', 'descr':'General Interface Signals', 'ports': [
        {'name':'clk_i', 'type':'I', 'n_bits':'1', 'descr':'System clock input.'},
        {'name':'rst_i', 'type':'I', 'n_bits':'1', 'descr':'System reset, asynchronous and active high.'}
    ]}
]

regs = \
[
    {'name': 'cache', 'descr':'CACHE software accessible registers.', 'regs': [
        {'name':'WTB_EMPTY', 'type':"R", 'n_bits':1, 'rst_val':0, 'addr':0, 'log2n_items':0, 'autologic':False, 'descr':"Write-through buffer empty (1) or non-empty (0)."},
        {'name':'WTB_FULL', 'type':"R", 'n_bits':1, 'rst_val':0, 'addr':1, 'log2n_items':0, 'autologic':False, 'descr':"Write-through buffer full (1) or non-full (0)."},
        {'name':'RW_HIT', 'type':"R", 'n_bits':32, 'rst_val':0, 'addr':4, 'log2n_items':0, 'autologic':False, 'descr':"Read and write hit counter."},
        {'name':'RW_MISS', 'type':"R", 'n_bits':32, 'rst_val':0, 'addr':8, 'log2n_items':0, 'autologic':False, 'descr':"Read and write miss counter."},
        {'name':'READ_HIT', 'type':"R", 'n_bits':32, 'rst_val':0, 'addr':12, 'log2n_items':0, 'autologic':False, 'descr':"Read hit counter."},
        {'name':'READ_MISS', 'type':"R", 'n_bits':32, 'rst_val':0, 'addr':16, 'log2n_items':0, 'autologic':False, 'descr':"Read miss counter."},
        {'name':'WRITE_HIT', 'type':"R", 'n_bits':32, 'rst_val':0, 'addr':20, 'log2n_items':0, 'autologic':False, 'descr':"Write hit counter."},
        {'name':'WRITE_MISS', 'type':"R", 'n_bits':32, 'rst_val':0, 'addr':24, 'log2n_items':0, 'autologic':False, 'descr':"Write miss counter."},
        {'name':'RST_CNTRS', 'type':"W", 'n_bits':1, 'rst_val':0, 'addr':28, 'log2n_items':0, 'autologic':False, 'descr':"Reset read/write hit/miss counters by writing any value to this register."},
        {'name':'INVALIDATE', 'type':"W", 'n_bits':1, 'rst_val':0, 'addr':32, 'log2n_items':0, 'autologic':False, 'descr':"Invalidate the cache data contents by writing any value to this register."},
        {'name':'VERSION', 'type':"R", 'n_bits':32, 'rst_val':0, 'addr':36, 'log2n_items':0, 'autologic':False, 'descr':"Cache version."}
    ]}
]

blocks = []

# Main function to setup this core and its components
def main():
    # Setup this system
    setup.setup(sys.modules[__name__])

if __name__ == "__main__":
    main()
