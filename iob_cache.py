# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT


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
    be_if = "axi" if BE_IF == "AXI4" else "iob"
    NAME = py_params.get("name", f"iob_cache_{be_if}")
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
        "generate_hw": True,
        "board_list": ["iob_aes_ku040_db_g"],
    }
    #
    # Confs
    #
    config_macros = [
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
    ]
    attributes_dict["confs"] = config_macros + [
        # Currently, Py2hwsw does not have a way of adding `includes. So we need to repeat this macro manually here
        {
            "name": "ADDR_W_CSRS",
            "descr": "Address width of CSRs",
            "type": "M",
            "val": "5",
            "min": "?",
            "max": "?",
        },
        #
        # Verilog Parameters
        #
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
        # Derived parameters
        {
            "name": "FE_NBYTES",
            "type": "D",
            "val": "FE_DATA_W / 8",
            "min": "0",
            "max": "32",
        },
        {
            "name": "FE_NBYTES_W",
            "type": "D",
            "val": "$clog2(FE_NBYTES)",
            "min": "0",
            "max": "32",
        },
        {
            "name": "BE_NBYTES",
            "type": "D",
            "val": "BE_DATA_W / 8",
            "min": "0",
            "max": "32",
        },
        {
            "name": "BE_NBYTES_W",
            "type": "D",
            "val": "$clog2(BE_NBYTES)",
            "min": "0",
            "max": "32",
        },
        {
            "name": "LINE2BE_W",
            "type": "D",
            "val": "WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W)",
            "min": "0",
            "max": "32",
        },
        {
            "name": "ADDR_W",
            "descr": "Width of the (word aligned) front-end address bus, optionally including the highest bit to access cache controller CSRs (if enabled)",
            "type": "D",
            "val": "USE_CTRL + FE_ADDR_W - FE_NBYTES_W",
            "min": "NA",
            "max": "NA",
        },
        {
            "name": "DATA_W",
            "type": "D",
            "val": "FE_DATA_W",
            "min": "NA",
            "max": "NA",
        },
    ]
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
                "descr": "AXI ID width",
                "type": "P",
                "val": "1",
                "min": "0",
                "max": "32",
            },
            {
                "name": "AXI_ID",
                "descr": "AXI ID",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "32",
            },
            {
                "name": "AXI_LEN_W",
                "descr": "AXI length",
                "type": "P",
                "val": "4",
                "min": "0",
                "max": "32",
            },
            {
                "name": "AXI_ADDR_W",
                "descr": "AXI address width",
                "type": "P",
                "val": "BE_ADDR_W",
                "min": "0",
                "max": "32",
            },
            {
                "name": "AXI_DATA_W",
                "descr": "AXI data width",
                "type": "P",
                "val": "BE_DATA_W",
                "min": "0",
                "max": "32",
            },
        ]

    #
    # Ports
    #
    attributes_dict["ports"] = [
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
    ]
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
                    "LOCK_W": 1,
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
    #
    # Wires
    #
    attributes_dict["wires"] = [
        # Front-end
        {
            "name": "fe_cache_mem",
            "descr": "Cache memory front-end interface",
            "signals": [
                {"name": "data_req", "width": 1},
                {"name": "data_addr", "width": "FE_ADDR_W - FE_NBYTES_W"},
                {"name": "data_rdata", "width": "FE_DATA_W"},
                {"name": "data_ack", "width": 1},
                {"name": "data_req_reg", "width": 1},
                {"name": "data_addr_reg", "width": "FE_ADDR_W - FE_NBYTES_W"},
                {"name": "data_wdata_reg", "width": "FE_DATA_W"},
                {"name": "data_wstrb_reg", "width": "FE_NBYTES"},
            ],
        },
        {
            "name": "fe_ctrl",
            "descr": "Control interface.",
            "signals": [
                {"name": "ctrl_req", "width": 1},
                {"name": "ctrl_addr", "width": f"`{NAME.upper()}_ADDR_W_CSRS"},
                {"name": "ctrl_wstrb", "width": "DATA_W/8"},
                {"name": "ctrl_rdata", "width": "USE_CTRL*(FE_DATA_W-1)+1"},
                {"name": "ctrl_ack", "width": 1},
            ],
        },
        # Cache memory
        {
            "name": "cache_mem_fe",
            "descr": "Cache memory front-end interface",
            "signals": [
                {"name": "data_req"},
                {
                    "name": "cache_mem_data_addr",
                    "width": "FE_ADDR_W-(BE_NBYTES_W+LINE2BE_W)",
                },
                {"name": "data_rdata"},
                {"name": "data_ack"},
                {"name": "data_req_reg"},
                {"name": "data_addr_reg"},
                {"name": "data_wdata_reg"},
                {"name": "data_wstrb_reg"},
            ],
        },
        {
            "name": "be_write_if",
            "descr": "Back-end write channel",
            "signals": [
                {"name": "write_req", "width": 1},
                {
                    "name": "write_addr",
                    "width": "FE_ADDR_W - (FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W)",
                },
                {
                    "name": "write_wdata",
                    "width": "FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)",
                },
                {"name": "write_wstrb", "width": "FE_NBYTES"},
                {"name": "write_ack", "width": 1},
            ],
        },
        {
            "name": "be_read_if",
            "descr": "Back-end read channel",
            "signals": [
                {"name": "replace_req", "width": 1},
                {"name": "replace", "width": 1},
                {"name": "replace_addr", "width": "FE_ADDR_W-(BE_NBYTES_W+LINE2BE_W)"},
                {"name": "read_req", "width": 1},
                {"name": "read_addr", "width": "LINE2BE_W"},
                {"name": "read_rdata", "width": "BE_DATA_W"},
            ],
        },
        {
            "name": "cache_mem_ctrl",
            "descr": "",
            "signals": [
                {"name": "invalidate_o"},
                {"name": "wtbuf_full", "width": 1},
                {"name": "wtbuf_empty", "width": 1},
                {"name": "write_hit", "width": 1},
                {"name": "write_miss", "width": 1},
                {"name": "read_hit", "width": 1},
                {"name": "read_miss", "width": 1},
            ],
        },
        # Internal signals
        {
            "name": "ctrl_internal",
            "descr": "Internal signals for control interface.",
            "signals": [
                {"name": "ctrl_invalidate", "width": 1},
            ],
        },
    ]
    if BE_IF == "AXI4":
        attributes_dict["wires"] += [
            {
                "name": "clk_rst_s",
                "descr": "",
                "signals": [
                    {"name": "clk_i"},
                    {"name": "arst_i"},
                ],
            },
        ]
    #
    # Subblocks
    #
    attributes_dict["subblocks"] = [
        {
            "core_name": "iob_cache_front_end",
            "instance_name": "front_end",
            "instance_description": "This IOb interface is connected to a processor or any other processing element that needs a cache buffer to improve the performance of accessing a slower but larger memory",
            "parameters": {
                "ADDR_W": "ADDR_W",
                "DATA_W": "DATA_W",
                "USE_CTRL": "USE_CTRL",
            },
            "connect": {
                "clk_en_rst_s": "clk_en_rst_s",
                "iob_s": "iob_s",
                "cache_mem_io": "fe_cache_mem",
                "ctrl_io": "fe_ctrl",
            },
        },
        {
            "core_name": "iob_cache_memory",
            "instance_name": "cache_memory",
            "instance_description": "This block contains the tag, data storage memories and the Write Through Buffer if the correspeonding write policy is selected; these memories are implemented either with RAM if large enough, or with registers if small enough",
            "config_macros": config_macros,
            "parameters": {
                "FE_ADDR_W": "FE_ADDR_W",
                "FE_DATA_W": "FE_DATA_W",
                "BE_DATA_W": "BE_DATA_W",
                "NWAYS_W": "NWAYS_W",
                "NLINES_W": "NLINES_W",
                "WORD_OFFSET_W": "WORD_OFFSET_W",
                "WTBUF_DEPTH_W": "WTBUF_DEPTH_W",
                "REP_POLICY": "REP_POLICY",
                "WRITE_POL": "WRITE_POL",
                "USE_CTRL": "USE_CTRL",
                "USE_CTRL_CNT": "USE_CTRL_CNT",
            },
            "connect": {
                "clk_en_rst_s": "clk_en_rst_s",
                "fe_io": "cache_mem_fe",
                "be_write_io": "be_write_if",
                "be_read_io": "be_read_if",
                "ctrl_io": "cache_mem_ctrl",
            },
        },
    ]
    if BE_IF == "AXI4":
        attributes_dict["subblocks"] += [
            {
                "core_name": "iob_cache_back_end_axi",
                "instance_name": "back_end_axi",
                "instance_description": "Memory-side interface: if the cache is at the last level before the target memory module, the back-end interface connects to the target memory (e.g. DDR) controller; if the cache is not at the last level, the back-end interface connects to the next-level cache. This module implements an AXI4 interface",
                "parameters": {
                    "FE_ADDR_W": "FE_ADDR_W",
                    "FE_DATA_W": "FE_DATA_W",
                    "BE_ADDR_W": "BE_ADDR_W",
                    "BE_DATA_W": "BE_DATA_W",
                    "WORD_OFFSET_W": "WORD_OFFSET_W",
                    "WRITE_POL": "WRITE_POL",
                    "AXI_ADDR_W": "AXI_ADDR_W",
                    "AXI_DATA_W": "AXI_DATA_W",
                    "AXI_ID_W": "AXI_ID_W",
                    "AXI_LEN_W": "AXI_LEN_W",
                    "AXI_ID": "AXI_ID",
                },
                "connect": {
                    "clk_rst_s": "clk_rst_s",
                    "write_io": "be_write_if",
                    "read_io": "be_read_if",
                    "axi_m": "axi_m",
                },
            },
        ]
    elif BE_IF == "IOb":
        attributes_dict["subblocks"] += [
            {
                "core_name": "iob_cache_back_end_iob",
                "instance_name": "back_end_iob",
                "instance_description": "Memory-side interface: if the cache is at the last level before the target memory module, the back-end interface connects to the target memory (e.g. DDR) controller; if the cache is not at the last level, the back-end interface connects to the next-level cache. This module implements an IOb interface",
                "parameters": {
                    "FE_ADDR_W": "FE_ADDR_W",
                    "FE_DATA_W": "FE_DATA_W",
                    "BE_ADDR_W": "BE_ADDR_W",
                    "BE_DATA_W": "BE_DATA_W",
                    "WORD_OFFSET_W": "WORD_OFFSET_W",
                    "WRITE_POL": "WRITE_POL",
                },
                "connect": {
                    "clk_en_rst_s": "clk_en_rst_s",
                    "write_io": "be_write_if",
                    "read_io": "be_read_if",
                    "iob_m": "iob_m",
                },
            },
        ]
    attributes_dict["subblocks"] += [
        {
            "core_name": "iob_cache_control",
            "instance_name": "cache_control",
            "be_if": be_if,
            "instantiate": False,  # Instantiated manually in the verilog snippet
        },
        # Generate CSRs but don't instantiate it (generated hardware unused; only for software and docs)
        {
            "core_name": "iob_csrs",
            "instance_name": "csrs_inst",
            "name": f"iob_cache_{be_if}_csrs",
            "instantiate": False,
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
        # For simulation
        {
            "core_name": "iob_tasks",
            "instance_name": "iob_tasks_inst",
            "dest_dir": "hardware/simulation/src",
            "instantiate": False,
        },
    ]
    #
    # Superblocks
    #
    attributes_dict["superblocks"] = [
        # Simulation wrapper
        {
            "core_name": "iob_cache_sim_wrapper",
            "dest_dir": "hardware/simulation/src",
            "cache_confs": [
                conf for conf in attributes_dict["confs"] if conf["type"] in ["P", "D"]
            ],
            "be_if": be_if,
        },
    ]
    #
    # Software Modules
    #
    attributes_dict["sw_modules"] = [
        {
            "core_name": "iob_coverage_analyze",
            "instance_name": "iob_coverage_analyze_inst",
        },
    ]
    #
    # Combinatorial
    #
    attributes_dict["comb"] = {
        "code": """
   invalidate_o = ctrl_invalidate | invalidate_i;
   wtb_empty_o  = wtbuf_empty & wtb_empty_i;
   cache_mem_data_addr = data_addr[FE_ADDR_W-FE_NBYTES_W-1:BE_NBYTES_W+LINE2BE_W-FE_NBYTES_W];

"""
    }
    #
    # Snippets
    #
    attributes_dict["snippets"] = [
        {
            "verilog_code": """
   //Cache control & Cache controller: this block is used for invalidating the cache, monitoring the status of the Write Thorough buffer, and accessing read/write hit/miss counters.
   generate
      if (USE_CTRL) begin : g_ctrl
         iob_cache_control #(
            .DATA_W      (FE_DATA_W),
            .USE_CTRL_CNT(USE_CTRL_CNT)
         ) cache_control (
            .clk_i  (clk_i),
            .cke_i  (cke_i),
            .arst_i (arst_i),

            // control's signals
            .valid_i(ctrl_req),
            .addr_i (ctrl_addr),
            .wstrb_i (ctrl_wstrb),

            // write data
            .wtbuf_full_i (wtbuf_full),
            .wtbuf_empty_i(wtbuf_empty),
            .write_hit_i  (write_hit),
            .write_miss_i (write_miss),
            .read_hit_i   (read_hit),
            .read_miss_i  (read_miss),

            .rdata_o     (ctrl_rdata),
            .ready_o     (ctrl_ack),
            .invalidate_o(ctrl_invalidate)
         );
      end else begin : g_no_ctrl
         assign ctrl_rdata      = 1'b0;
         assign ctrl_ack        = 1'b0;
         assign ctrl_invalidate = 1'b0;
      end
   endgenerate
"""
        }
    ]

    return attributes_dict
