# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT

import os
import shutil


def setup(py_params: dict):
    VERSION = "0.71"

    #
    # List of supported python parameters
    #

    # Backend interface data width
    BE_DATA_W = py_params.get("be_data_w", "32")
    # Backend interface type
    BE_IF = py_params.get("be_if", "AXI4")
    # Name of generated cache's verilog. We may use multiple names to generate caches with different configurations.
    suffix = 'axi' if BE_IF == 'AXI4' else 'iob'
    NAME = py_params.get("name", f"iob_cache_{suffix}")
    # Build directory. Usually auto-filled by Py2HWSW.
    BUILD_DIR = py_params.get("build_dir", "") or f"../{NAME}_V{VERSION}"

    # Check if parameters are valid
    assert BUILD_DIR, "Build directory is empty"
    if BE_DATA_W not in ["32", "64", "128", "256"]:
        print("ERROR: backend interface width must be 32, 64, 128 or 256")
        exit(1)
    if BE_IF not in ["AXI4", "IOb"]:
        print("ERROR: backend interface must be either AXI4 or IOb")
        exit(1)

    # Create dictionary with attributes of cache
    attributes_dict = {
        "name": NAME,
        "version": VERSION,
        "build_dir": BUILD_DIR,
        "generate_hw": False,
        "board_list": ["aes_ku040_db_g"],
        #
        # Confs
        #
        "confs": [
            {
                "name": "LRU",
                "descr": "Least Recently Used -- more resources intensive - N*log2(N) bits per cache line - Uses counters",
                "type": "M",
                "val": "0",
                "min": "?",
                "max": "?",
            },
            {
                "name": "PLRU_MRU",
                "descr": "bit-based Pseudo-Least-Recently-Used, a simpler replacement policy than LRU, using a much lower complexity (lower resources) - N bits per cache line",
                "type": "M",
                "val": "1",
                "min": "?",
                "max": "?",
            },
            {
                "name": "PLRU_TREE",
                "descr": "tree-based Pseudo-Least-Recently-Used, uses a tree that updates after any way received an hit, and points towards the oposing one. Uses less resources than bit-pseudo-lru - N-1 bits per cache line",
                "type": "M",
                "val": "2",
                "min": "?",
                "max": "?",
            },
            # Write Policy
            {
                "name": "WRITE_THROUGH",
                "descr": "write-through not allocate: implements a write-through buffer",
                "type": "M",
                "val": "0",
                "min": "?",
                "max": "?",
            },
            {
                "name": "WRITE_BACK",
                "descr": "write-back allocate: implementes a dirty-memory",
                "type": "M",
                "val": "1",
                "min": "?",
                "max": "?",
            },
            # csrs_gen parameters
            {
                "name": "ADDR_W",
                "descr": "Cache address width used by csrs_gen",
                "type": "P",
                "val": "`IOB_CACHE_CSRS_ADDR_W",
                "min": "NA",
                "max": "NA",
            },
            {
                "name": "DATA_W",
                "descr": "Cache data width used by csrs_gen",
                "type": "P",
                "val": "32",
                "min": "NA",
                "max": "NA",
            },
            {
                "name": "FE_ADDR_W",
                "descr": "Front-end address width (log2): defines the total memory space accessible via the cache, which must be a power of two.",
                "type": "P",
                "val": "24",
                "min": "1",
                "max": "64",
            },
            {
                "name": "FE_DATA_W",
                "descr": "Front-end data width (log2): this parameter allows supporting processing elements with various data widths.",
                "type": "P",
                "val": "32",
                "min": "32",
                "max": "64",
            },
            {
                "name": "BE_ADDR_W",
                "descr": "Back-end address width (log2): the value of this parameter must be equal or greater than FE_ADDR_W to match the width of the back-end interface, but the address space is still dictated by ADDR_W.",
                "type": "P",
                "val": "24",
                "min": "1",
                "max": "",
            },
            {
                "name": "BE_DATA_W",
                "descr": "Back-end data width (log2): the value of this parameter must be an integer  multiple $k \\geq 1$ of DATA_W. If $k>1$, the memory controller can operate at a frequency higher than the cache's frequency. Typically, the memory controller has an asynchronous FIFO interface, so that it can sequentially process multiple commands received in paralell from the cache's back-end interface. ",
                "type": "P",
                "val": BE_DATA_W,
                "min": "32",
                "max": "256",
            },
            {
                "name": "NWAYS_W",
                "descr": "Number of cache ways (log2): the miminum is 0 for a directly mapped cache; the default is 1 for a two-way cache; the maximum is limited by the desired maximum operating frequency, which degrades with the number of ways. ",
                "type": "P",
                "val": "1",
                "min": "0",
                "max": "8",
            },
            {
                "name": "NLINES_W",
                "descr": "Line offset width (log2): the value of this parameter equals the number of cache lines, given by 2**NLINES_W.",
                "type": "P",
                "val": "7",
                "min": "",
                "max": "",
            },
            {
                "name": "WORD_OFFSET_W",
                "descr": "Word offset width (log2):  the value of this parameter equals the number of words per line, which is 2**OFFSET_W. ",
                "type": "P",
                "val": "3",
                "min": "1",
                "max": "",
            },
            {
                "name": "WTBUF_DEPTH_W",
                "descr": "Write-through buffer depth (log2). A shallow buffer will fill up more frequently and cause write stalls; however, on a Read After Write (RAW) event, a shallow buffer will empty faster, decreasing the duration of the read stall. A deep buffer is unlkely to get full and cause write stalls; on the other hand, on a RAW event, it will take a long time to empty and cause long read stalls.",
                "type": "P",
                "val": "4",
                "min": "",
                "max": "",
            },
            {
                "name": "REP_POLICY",
                "descr": "Line replacement policy: set to 0 for Least Recently Used (LRU); set to 1 for Pseudo LRU based on Most Recently Used (PLRU_MRU); set to 2 for tree-based Pseudo LRU (PLRU_TREE).",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "3",
            },
            {
                "name": "WRITE_POL",
                "descr": "Write policy: set to 0 for write-through or set to 1 for write-back.",
                "type": "P",
                "val": "0 ",
                "min": "0",
                "max": "1",
            },
            {
                "name": "USE_CTRL",
                "descr": "Instantiates a cache controller (1) or not (0). The cache controller provides memory-mapped software accessible registers to invalidate the cache data contents, and monitor the write through buffer status using the front-end interface. To access the cache controller, the MSB of the address mut be set to 1. For more information refer to the example software functions provided.",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "1",
            },
            {
                "name": "USE_CTRL_CNT",
                "descr": "Instantiates hit/miss counters for reads, writes or both (1), or not (0). This parameter is meaningful if the cache controller is present (USE_CTRL: 1), providing additional software accessible functions for these functions.",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "1",
            },
        ]
    }
    if BE_IF == "AXI4":
        attributes_dict["confs"] += [
            {
                "name": "AXI",
                "descr": "AXI interface used by backend",
                "type": "M",
                "val": "NA",
                "min": "NA",
                "max": "NA",
            },
            {
                "name": "AXI_ID_W",
                "descr": "description",
                "type": "M",
                "val": "1",
                "min": "?",
                "max": "?",
            },
            {
                "name": "AXI_LEN_W",
                "descr": "description",
                "type": "M",
                "val": "4",
                "min": "?",
                "max": "?",
            },
            {
                "name": "AXI_ID",
                "descr": "description",
                "type": "M",
                "val": "0",
                "min": "?",
                "max": "?",
            },
        ]

    attributes_dict |= {
        #
        # Ports
        #
        "ports": [
            {
                "name": "clk_en_rst_s",
                "descr": "Clock, clock enable and reset",
                "signals": {
                    "type": "iob_clk",
                },
            },
            {
                "name": "iob_s",
                "descr": "Front-end interface",
                "signals": {
                    "type": "iob",
                    "ADDR_W": "ADDR_W",
                    "DATA_W": "DATA_W",
                },
            },
            {
                "name": "ie_io",
                "descr": "Cache invalidate and write-trough buffer IO chain",
                "signals": [
                    {
                        "name": "invalidate_i",
                        "descr": "Invalidates all cache lines instantaneously if high.",
                        "width": 1,
                    },
                    {
                        "name": "invalidate_o",
                        "descr": "This output is asserted high when the cache is invalidated via the cache controller or the direct {\\tt invalidate_in} signal. The present {\\tt invalidate_out} signal is useful for invalidating the next-level cache if there is one. If not, this output should be floated.",
                        "width": 1,
                    },
                    {
                        "name": "wtb_empty_i",
                        "descr": "This input is driven by the next-level cache, if there is one, when its write-through buffer is empty. It should be tied high if there is no next-level cache. This signal is used to compute the overall empty status of a cache hierarchy, as explained for signal {\\tt wtb_empty_out}.",
                        "width": 1,
                    },
                    {
                        "name": "wtb_empty_o",
                        "descr": "This output is high if the cache's write-through buffer is empty and its {\tt wtb_empty_in} signal is high. This signal informs that all data written to the cache has been written to the destination memory module, and all caches on the way are empty.",
                        "width": 1,
                    },
                ],
            },
            # Interfaces for submodules
            # TODO: Move them to correct modules
            {
                "name": "axi_write_m",
                "descr": "AXI4 write interface",
                "signals": {
                    "type": "axi_write",
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                },
            },
            {
                "name": "axi_read_m",
                "descr": "AXI4 read interface",
                "signals": {
                    "type": "axi_read",
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                },
            },
            {
                "name": "fe_io",
                "descr": "Front-end interface (IOb native slave)",
                "signals": [
                    {
                        "name": "req_i",
                        "width": 1,
                        "descr": "Read or write request from host. If signal {\\tt ack} raises in the next cyle the request has been served; otherwise {\\tt req} should remain high until {\\tt ack} raises. When {\\tt ack} raises in response to a previous request, {\\tt req} may keep high, or combinatorially lowered in the same cycle. If {\\tt req} keeps high, a new request is being made to the current address {\\tt addr}; if {\\tt req} lowers, no new request is being made. Note that the new request is being made in parallel with acknowledging the previous request: pipelined operation.",
                    },
                    {
                        "name": "addr_i",
                        "width": "USE_CTRL+FE_ADDR_W-2",
                        "descr": "Address from CPU or other user core, excluding the byte selection LSBs.",
                    },
                    {
                        "name": "wdata_i",
                        "width": "FE_DATA_W",
                        "descr": "Write data fom host.",
                    },
                    {
                        "name": "wstrb_i",
                        "width": 4,
                        "descr": "Byte write strobe from host.",
                    },
                    {
                        "name": "rdata_o",
                        "width": "FE_DATA_W",
                        "descr": "Read data to host.",
                    },
                    {
                        "name": "ack_o",
                        "width": 1,
                        "descr": "Acknowledge signal from cache: indicates that the last request has been served. The next request can be issued as soon as this signal raises, in the same clock cycle, or later after it becomes low.",
                    },
                ],
            },
            {
                "name": "be_io",
                "descr": "Back-end interface",
                "signals": [
                    {
                        "name": "req_o",
                        "width": 1,
                        "descr": "Read or write request to next-level cache or memory.",
                    },
                    {
                        "name": "be_addr_o",
                        "width": "BE_ADDR_W",
                        "descr": "Address to next-level cache or memory.",
                    },
                    {
                        "name": "be_wdata_o",
                        "width": "BE_DATA_W",
                        "descr": "Write data to next-level cache or memory.",
                    },
                    {
                        "name": "be_wstrb_o",
                        "width": 4,
                        "descr": "Write strobe to next-level cache or memory.",
                    },
                    {
                        "name": "be_rdata_i",
                        "width": "BE_DATA_W",
                        "descr": "Read data from next-level cache or memory.",
                    },
                    {
                        "name": "be_ack_i",
                        "width": 1,
                        "descr": "Acknowledge signal from next-level cache or memory.",
                    },
                ],
            },
            # {
            #     "name": "ge_i",
            #     "descr": "General Interface Signals",
            #     "signals": [
            #         {
            #             "name": "clk_i",
            #             "width": 1,
            #             "descr": "System clock input.",
            #         },
            #         {
            #             "name": "rst_i",
            #             "width": 1,
            #             "descr": "System reset, asynchronous and active high.",
            #         },
            #     ],
            # },
        ],
    }
    # Back-end interface
    if BE_IF == "AXI4":
        attributes_dict["ports"] += [
            {
                "name": "axi_m",
                "descr": "Back-end interface",
                "signals": {
                    "type": "axi",
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                },
            },
        ]
    elif BE_IF == "IOb":
        attributes_dict["ports"] += [
            {
                "name": "iob_m",
                "descr": "Back-end interface",
                "signals": {
                    "type": "iob",
                    "prefix": "be_",
                    "ADDR_W": "BE_ADDR_W",
                    "DATA_W": "BE_DATA_W",
                },
            },
        ]
    attributes_dict |= {
        #
        # Subblocks
        #
        "subblocks": [
            {
                "core_name": "iob_csrs",
                "instance_name": "csrs_inst",
                "autoaddr": False,
                "rw_overlap": False,
                "version": VERSION,
                "csrs": [
                    {
                        "name": "cache",
                        "descr": "CACHE software accessible registers.",
                        "regs": [
                            {
                                "name": "WTB_EMPTY",
                                "descr": "Write-through buffer empty (1) or non-empty (0).",
                                "type": "NOAUTO",
                                "mode": "R",
                                "n_bits": 1,
                                "rst_val": 0,
                                "addr": 0,
                                "log2n_items": 0,
                            },
                            {
                                "name": "WTB_FULL",
                                "descr": "Write-through buffer full (1) or non-full (0).",
                                "type": "NOAUTO",
                                "mode": "R",
                                "n_bits": 1,
                                "rst_val": 0,
                                "addr": 1,
                                "log2n_items": 0,
                            },
                            {
                                "name": "RW_HIT",
                                "descr": "Read and write hit counter.",
                                "type": "NOAUTO",
                                "mode": "R",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 4,
                                "log2n_items": 0,
                            },
                            {
                                "name": "RW_MISS",
                                "descr": "Read and write miss counter.",
                                "type": "NOAUTO",
                                "mode": "R",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 8,
                                "log2n_items": 0,
                            },
                            {
                                "name": "READ_HIT",
                                "descr": "Read hit counter.",
                                "type": "NOAUTO",
                                "mode": "R",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 12,
                                "log2n_items": 0,
                            },
                            {
                                "name": "READ_MISS",
                                "descr": "Read miss counter.",
                                "type": "NOAUTO",
                                "mode": "R",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 16,
                                "log2n_items": 0,
                            },
                            {
                                "name": "WRITE_HIT",
                                "descr": "Write hit counter.",
                                "type": "NOAUTO",
                                "mode": "R",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 20,
                                "log2n_items": 0,
                            },
                            {
                                "name": "WRITE_MISS",
                                "descr": "Write miss counter.",
                                "type": "NOAUTO",
                                "mode": "R",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 24,
                                "log2n_items": 0,
                            },
                            {
                                "name": "RST_CNTRS",
                                "descr": "Reset read/write hit/miss counters by writing any value to this register.",
                                "type": "NOAUTO",
                                "mode": "W",
                                "n_bits": 1,
                                "rst_val": 0,
                                "addr": 28,
                                "log2n_items": 0,
                            },
                            {
                                "name": "INVALIDATE",
                                "descr": "Invalidate the cache data contents by writing any value to this register.",
                                "type": "NOAUTO",
                                "mode": "W",
                                "n_bits": 1,
                                "rst_val": 0,
                                "addr": 29,
                                "log2n_items": 0,
                            },
                        ],
                    },
                ],
            },
            {
                "core_name": "iob_regarray_sp",
                "instance_name": "iob_regarray_sp_inst",
            },
            {
                "core_name": "iob_fifo_sync",
                "instance_name": "iob_fifo_sync_inst",
            },
            {
                "core_name": "iob_reg",
                "instance_name": "iob_reg_inst",
            },
            {
                "core_name": "iob_reg",
                "instance_name": "iob_reg_care_inst",
                "port_params": {
                    "clk_en_rst_s": "c_a_r_e",
                },
            },
            {
                "core_name": "iob_ram_t2p",
                "instance_name": "iob_ram_t2p_inst",
            },
            {
                "core_name": "iob_ram_sp",
                "instance_name": "iob_ram_sp_inst",
            },
            {
                "core_name": "iob_tasks",
                "instance_name": "iob_tasks_inst",
                "dest_dir": "hardware/simulation/src",
            },
            {
                "core_name": "iob_ram_sp_be",
                "instance_name": "iob_ram_sp_be_inst",
            },
            {
                "core_name": "iob_axi_ram",
                "instance_name": "iob_axi_ram_inst",
            },
        ],
        "superblocks": [
            # Simulation wrapper
            {
                "core_name": "iob_cache_sim_wrapper",
                "dest_dir": "hardware/simulation/src",
                "cache_confs": [conf for conf in attributes_dict["confs"] if conf["type"] == "P"],
                "be_if": "axi" if BE_IF == "AXI4" else "iob",
            },
            # Kintex wrapper
            # {
            #     "core_name": "iob_cache_aes_ku040_db_g",
            #     "instance_description": "FPGA wrapper for aes_ku040_db_g board",
            #     "dest_dir": "hardware/fpga/vivado/iob_aes_ku040_db_g",
            # },
        ],
    }

    # Copy axi sources to build directory
    if py_params["py2hwsw_target"] == "setup" and BE_IF == "AXI4":
        os.makedirs(os.path.join(BUILD_DIR, "hardware/src"), exist_ok=True)
        for filename in [
            "iob_cache_axi.v",
            "iob_cache_back_end_axi.v",
            "iob_cache_write_channel_axi.v",
            "iob_cache_read_channel_axi.v",
        ]:
            shutil.copy(
                os.path.join(os.path.dirname(__file__), "hardware/axi_src", filename),
                os.path.join(BUILD_DIR, "hardware/src", filename),
            )

    return attributes_dict
