#!/usr/bin/env python3

import os
import sys

# Find python modules
if __name__ == "__main__":
    sys.path.append("../LIB/scripts")
from iob_module import iob_module

if __name__ == "__main__":
    iob_module.find_modules(search_path="..")

# Submodules
from iob_utils import iob_utils
from iob_regfile_sp import iob_regfile_sp
from iob_fifo_sync import iob_fifo_sync
from iob_ram_2p import iob_ram_2p
from iob_ram_sp import iob_ram_sp
from iob_reg import iob_reg
from iob_reg_re import iob_reg_re
from iob_ram_sp_be import iob_ram_sp_be


class iob_cache(iob_module):
    @classmethod
    def _init_attributes(cls):
        """Init module attributes"""
        cls.name = "iob_cache"
        cls.version = "V0.10"
        cls.flows = "emb sim doc fpga"
        cls.setup_dir = os.path.dirname(__file__)
        cls.BE_DATA_W = "32"
        for arg in sys.argv[1:]:
            if "BE_DATA_W" in arg:
                cls.BE_DATA_W = arg.split("=")[1]
                if cls.BE_DATA_W not in ["32", "64", "128", "256"]:
                    print("ERROR: backend interface width must be 32, 64, 128 or 256")
                    exit(1)

        # Parse BE_IF argument
        cls.BE_IF = "AXI4"
        for arg in sys.argv[1:]:
            if "BE_IF" in arg:
                cls.BE_IF = arg.split("=")[1]
                if cls.BE_IF not in ["AXI4", "IOb"]:
                    print("ERROR: backend interface must be either AXI4 or IOb")
                    exit(1)

        cls.AXI_CONFS = []
        if cls.BE_IF == "AXI4":
            cls.AXI_CONFS = [
                {
                    "name": "AXI",
                    "type": "M",
                    "val": "NA",
                    "min": "NA",
                    "max": "NA",
                    "descr": "AXI interface used by backend",
                },
                {
                    "name": "AXI_ID_W",
                    "type": "M",
                    "val": "1",
                    "min": "?",
                    "max": "?",
                    "descr": "description",
                },
                {
                    "name": "AXI_LEN_W",
                    "type": "M",
                    "val": "4",
                    "min": "?",
                    "max": "?",
                    "descr": "description",
                },
                {
                    "name": "AXI_ID",
                    "type": "M",
                    "val": "0",
                    "min": "?",
                    "max": "?",
                    "descr": "description",
                },
            ]

        cls.submodules = [
            iob_utils,
            iob_regfile_sp,
            iob_fifo_sync,
            (iob_ram_2p, {"purpose": "simulation"}),
            (iob_ram_2p, {"purpose": "fpga"}),
            (iob_ram_sp, {"purpose": "simulation"}),
            (iob_ram_sp, {"purpose": "fpga"}),
            iob_reg,
            iob_reg_re,
            # Simulation headers & modules
            (iob_ram_sp_be, {"purpose": "simulation"}),
        ]

        cls.confs = [
            # Macros
            # Replacement Policy
            {
                "name": "LRU",
                "type": "M",
                "val": "0",
                "min": "?",
                "max": "?",
                "descr": "Least Recently Used -- more resources intensive - N*log2(N) bits per cache line - Uses counters",
            },
            {
                "name": "PLRU_MRU",
                "type": "M",
                "val": "1",
                "min": "?",
                "max": "?",
                "descr": "bit-based Pseudo-Least-Recently-Used, a simpler replacement policy than LRU, using a much lower complexity (lower resources) - N bits per cache line",
            },
            {
                "name": "PLRU_TREE",
                "type": "M",
                "val": "2",
                "min": "?",
                "max": "?",
                "descr": "tree-based Pseudo-Least-Recently-Used, uses a tree that updates after any way received an hit, and points towards the oposing one. Uses less resources than bit-pseudo-lru - N-1 bits per cache line",
            },
            # Write Policy
            {
                "name": "WRITE_THROUGH",
                "type": "M",
                "val": "0",
                "min": "?",
                "max": "?",
                "descr": "write-through not allocate: implements a write-through buffer",
            },
            {
                "name": "WRITE_BACK",
                "type": "M",
                "val": "1",
                "min": "?",
                "max": "?",
                "descr": "write-back allocate: implementes a dirty-memory",
            },
            # Swreg_gen parameters
            {
                "name": "ADDR_W",
                "type": "P",
                "val": "`IOB_CACHE_SWREG_ADDR_W",
                "min": "NA",
                "max": "NA",
                "descr": "Cache address width used by swreg_gen",
            },
            {
                "name": "DATA_W",
                "type": "P",
                "val": "32",
                "min": "NA",
                "max": "NA",
                "descr": "Cache data width used by swreg_gen",
            },
            {
                "name": "FE_ADDR_W",
                "type": "P",
                "val": "24",
                "min": "1",
                "max": "64",
                "descr": "Front-end address width (log2): defines the total memory space accessible via the cache, which must be a power of two.",
            },
            {
                "name": "FE_DATA_W",
                "type": "P",
                "val": "32",
                "min": "32",
                "max": "64",
                "descr": "Front-end data width (log2): this parameter allows supporting processing elements with various data widths.",
            },
            {
                "name": "BE_ADDR_W",
                "type": "P",
                "val": "24",
                "min": "1",
                "max": "",
                "descr": "Back-end address width (log2): the value of this parameter must be equal or greater than FE_ADDR_W to match the width of the back-end interface, but the address space is still dictated by ADDR_W.",
            },
            {
                "name": "BE_DATA_W",
                "type": "P",
                "val": cls.BE_DATA_W,
                "min": "32",
                "max": "256",
                "descr": "Back-end data width (log2): the value of this parameter must be an integer  multiple $k \geq 1$ of DATA_W. If $k>1$, the memory controller can operate at a frequency higher than the cache's frequency. Typically, the memory controller has an asynchronous FIFO interface, so that it can sequentially process multiple commands received in paralell from the cache's back-end interface. ",
            },
            {
                "name": "NWAYS_W",
                "type": "P",
                "val": "1",
                "min": "0",
                "max": "8",
                "descr": "Number of cache ways (log2): the miminum is 0 for a directly mapped cache; the default is 1 for a two-way cache; the maximum is limited by the desired maximum operating frequency, which degrades with the number of ways. ",
            },
            {
                "name": "NLINES_W",
                "type": "P",
                "val": "7",
                "min": "",
                "max": "",
                "descr": "Line offset width (log2): the value of this parameter equals the number of cache lines, given by 2**NLINES_W.",
            },
            {
                "name": "WORD_OFFSET_W",
                "type": "P",
                "val": "3",
                "min": "0",
                "max": "",
                "descr": "Word offset width (log2):  the value of this parameter equals the number of words per line, which is 2**OFFSET_W. ",
            },
            {
                "name": "WTBUF_DEPTH_W",
                "type": "P",
                "val": "4",
                "min": "",
                "max": "",
                "descr": "Write-through buffer depth (log2). A shallow buffer will fill up more frequently and cause write stalls; however, on a Read After Write (RAW) event, a shallow buffer will empty faster, decreasing the duration of the read stall. A deep buffer is unlkely to get full and cause write stalls; on the other hand, on a RAW event, it will take a long time to empty and cause long read stalls.",
            },
            {
                "name": "REP_POLICY",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "3",
                "descr": "Line replacement policy: set to 0 for Least Recently Used (LRU); set to 1 for Pseudo LRU based on Most Recently Used (PLRU_MRU); set to 2 for tree-based Pseudo LRU (PLRU_TREE).",
            },
            {
                "name": "WRITE_POL",
                "type": "P",
                "val": "0 ",
                "min": "0",
                "max": "1",
                "descr": "Write policy: set to 0 for write-through or set to 1 for write-back.",
            },
            {
                "name": "USE_CTRL",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "1",
                "descr": "Instantiates a cache controller (1) or not (0). The cache controller provides memory-mapped software accessible registers to invalidate the cache data contents, and monitor the write through buffer status using the front-end interface. To access the cache controller, the MSB of the address mut be set to 1. For more information refer to the example software functions provided.",
            },
            {
                "name": "USE_CTRL_CNT",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "1",
                "descr": "Instantiates hit/miss counters for reads, writes or both (1), or not (0). This parameter is meaningful if the cache controller is present (USE_CTRL=1), providing additional software accessible functions for these functions.",
            },
        ] + cls.AXI_CONFS

        cls.ios += [
            {
                "name": "clk_en_rst",
                "type": "slave",
                "port_prefix": "",
                "wire_prefix": "",
                "descr": "Clock, clock enable and reset",
                "ports": [],
            },
            {
                "name": "iob",
                "type": "slave",
                "port_prefix": "",
                "wire_prefix": "",
                "descr": "Front-end interface",
                "ports": [],
            },
            {
                "name": "iob",
                "type": "master",
                "port_prefix": "be_",
                "wire_prefix": "be_",
                "descr": "Back-end interface",
                "ports": [],
            },
            {
                "name": "axi",
                "type": "master",
                "port_prefix": "",
                "wire_prefix": "",
                "descr": "AXI4 interface",
                "ports": [],
                "widths": {
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                },
            },
            {
                "name": "axi_write",
                "type": "master",
                "port_prefix": "",
                "wire_prefix": "",
                "descr": "AXI4 write interface",
                "ports": [],
                "widths": {
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                },
            },
            {
                "name": "axi_read",
                "type": "master",
                "port_prefix": "",
                "wire_prefix": "",
                "descr": "AXI4 read interface",
                "ports": [],
                "widths": {
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                },
            },
            {
                "name": "fe",
                "type": "slave",
                "port_prefix": "",
                "wire_prefix": "",
                "descr": "Front-end interface (IOb native slave)",
                "ports": [
                    {
                        "name": "req",
                        "direction": "input",
                        "width": 1,
                        "descr": "Read or write request from host. If signal {\\tt ack} raises in the next cyle the request has been served; otherwise {\\tt req} should remain high until {\\tt ack} raises. When {\\tt ack} raises in response to a previous request, {\\tt req} may keep high, or combinatorially lowered in the same cycle. If {\\tt req} keeps high, a new request is being made to the current address {\\tt addr}; if {\\tt req} lowers, no new request is being made. Note that the new request is being made in parallel with acknowledging the previous request: pipelined operation.",
                    },
                    {
                        "name": "addr",
                        "direction": "input",
                        "width": "USE_CTRL+FE_ADDR_W-2",
                        "descr": "Address from CPU or other user core, excluding the byte selection LSBs.",
                    },
                    {
                        "name": "wdata",
                        "direction": "input",
                        "width": "FE_DATA_W",
                        "descr": "Write data fom host.",
                    },
                    {
                        "name": "wstrb",
                        "direction": "input",
                        "width": 4,
                        "descr": "Byte write strobe from host.",
                    },
                    {
                        "name": "rdata",
                        "direction": "output",
                        "width": "FE_DATA_W",
                        "descr": "Read data to host.",
                    },
                    {
                        "name": "ack",
                        "direction": "output",
                        "width": 1,
                        "descr": "Acknowledge signal from cache: indicates that the last request has been served. The next request can be issued as soon as this signal raises, in the same clock cycle, or later after it becomes low.",
                    },
                ],
            },
            {
                "name": "be",
                "type": "slave",
                "port_prefix": "",
                "wire_prefix": "",
                "descr": "Back-end interface",
                "ports": [
                    {
                        "name": "req",
                        "direction": "output",
                        "width": 1,
                        "descr": "Read or write request to next-level cache or memory.",
                    },
                    {
                        "name": "be_addr",
                        "direction": "output",
                        "width": "BE_ADDR_W",
                        "descr": "Address to next-level cache or memory.",
                    },
                    {
                        "name": "be_wdata",
                        "direction": "output",
                        "width": "BE_DATA_W",
                        "descr": "Write data to next-level cache or memory.",
                    },
                    {
                        "name": "be_wstrb",
                        "direction": "output",
                        "width": 4,
                        "descr": "Write strobe to next-level cache or memory.",
                    },
                    {
                        "name": "be_rdata",
                        "direction": "input",
                        "width": "BE_DATA_W",
                        "descr": "Read data from next-level cache or memory.",
                    },
                    {
                        "name": "be_ack",
                        "direction": "input",
                        "width": 1,
                        "descr": "Acknowledge signal from next-level cache or memory.",
                    },
                ],
            },
            {
                "name": "ie",
                "type": "master",
                "port_prefix": "",
                "wire_prefix": "",
                "descr": "Cache invalidate and write-trough buffer IO chain",
                "ports": [
                    {
                        "name": "invalidate_in",
                        "direction": "input",
                        "width": 1,
                        "descr": "Invalidates all cache lines instantaneously if high.",
                    },
                    {
                        "name": "invalidate_out",
                        "direction": "output",
                        "width": 1,
                        "descr": "This output is asserted high when the cache is invalidated via the cache controller or the direct {\\tt invalidate_in} signal. The present {\\tt invalidate_out} signal is useful for invalidating the next-level cache if there is one. If not, this output should be floated.",
                    },
                    {
                        "name": "wtb_empty_in",
                        "direction": "input",
                        "width": 1,
                        "descr": "This input is driven by the next-level cache, if there is one, when its write-through buffer is empty. It should be tied high if there is no next-level cache. This signal is used to compute the overall empty status of a cache hierarchy, as explained for signal {\\tt wtb_empty_out}.",
                    },
                    {
                        "name": "wtb_empty_out",
                        "direction": "output",
                        "width": 1,
                        "descr": "This output is high if the cache's write-through buffer is empty and its {\tt wtb_empty_in} signal is high. This signal informs that all data written to the cache has been written to the destination memory module, and all caches on the way are empty.",
                    },
                ],
            },
            {
                "name": "ge",
                "type": "slave",
                "port_prefix": "",
                "wire_prefix": "",
                "descr": "General Interface Signals",
                "ports": [
                    {
                        "name": "clk_i",
                        "direction": "input",
                        "width": 1,
                        "descr": "System clock input.",
                    },
                    {
                        "name": "rst_i",
                        "direction": "input",
                        "width": 1,
                        "descr": "System reset, asynchronous and active high.",
                    },
                ],
            },
        ]

        cls.autoaddr = False
        cls.regs += [
            {
                "name": "cache",
                "descr": "CACHE software accessible registers.",
                "regs": [
                    {
                        "name": "WTB_EMPTY",
                        "type": "R",
                        "n_bits": 1,
                        "rst_val": 0,
                        "addr": 0,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Write-through buffer empty (1) or non-empty (0).",
                    },
                    {
                        "name": "WTB_FULL",
                        "type": "R",
                        "n_bits": 1,
                        "rst_val": 0,
                        "addr": 1,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Write-through buffer full (1) or non-full (0).",
                    },
                    {
                        "name": "RW_HIT",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": 4,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Read and write hit counter.",
                    },
                    {
                        "name": "RW_MISS",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": 8,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Read and write miss counter.",
                    },
                    {
                        "name": "READ_HIT",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": 12,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Read hit counter.",
                    },
                    {
                        "name": "READ_MISS",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": 16,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Read miss counter.",
                    },
                    {
                        "name": "WRITE_HIT",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": 20,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Write hit counter.",
                    },
                    {
                        "name": "WRITE_MISS",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": 24,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Write miss counter.",
                    },
                    {
                        "name": "RST_CNTRS",
                        "type": "W",
                        "n_bits": 1,
                        "rst_val": 0,
                        "addr": 28,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Reset read/write hit/miss counters by writing any value to this register.",
                    },
                    {
                        "name": "INVALIDATE",
                        "type": "W",
                        "n_bits": 1,
                        "rst_val": 0,
                        "addr": 29,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Invalidate the cache data contents by writing any value to this register.",
                    },
                ],
            }
        ]

        cls.block_groups += []


if __name__ == "__main__":
    iob_cache.setup_as_top_module()
