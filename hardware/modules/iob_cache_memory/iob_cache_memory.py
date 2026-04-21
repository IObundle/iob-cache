# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params: dict):
    assert py_params.get(
        "config_macros", ""
    ), "Cache memory needs cache's configuration macros, like LRU, PLRU_MRU, etc."

    # Create dictionary with attributes of cache
    attributes_dict = {
        "generate_hw": False,
    }
    #
    # Confs
    #
    attributes_dict["confs"] = py_params["config_macros"] + [
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
            "name": "BE_DATA_W",
            "descr": "Back-end data width (log2): the value of this parameter must be an integer  multiple $k \\geq 1$ of DATA_W. If $k>1$, the memory controller can operate at a frequency higher than the cache's frequency. Typically, the memory controller has an asynchronous FIFO interface, so that it can sequentially process multiple commands received in paralell from the cache's back-end interface. ",
            "type": "P",
            "val": "32",
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
            "name": "SET_INDEX_W",
            "descr": "Width (in bits) of the cache's set index field. The number of sets in the cache is calculated as 2**SET_INDEX_W. Combined with the number of ways (NWAYS), the total number of cache lines in the cache is NWAYS*(2**SET_INDEX_W)."
            "- For a fully associative cache, `SET_INDEX_W` is `0` (as the entire cache forms a single set). "
            "- For a direct-mapped cache (which has `NWAYS = 1`), `SET_INDEX_W` specifies the log2 number of sets, each containing a single cache line, therefore is also equivalent to the log2 total number of cache lines.",
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
            "type": "D",
            "val": "FE_ADDR_W-(BE_NBYTES_W+LINE2BE_W)",
            "min": "0",
            "max": "32",
        },
        {
            "name": "ADDR_REG_W",
            "type": "D",
            "val": "FE_ADDR_W-FE_NBYTES_W",
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
            "descr": "Clock, clock enable and synchronous reset",
            "signals": {
                "type": "iob_clk",
            },
        },
        {
            "name": "fe_io",
            "descr": "Cache memory front-end interface",
            "signals": [
                {"name": "req_i", "width": 1},
                {"name": "addr_i", "width": "ADDR_W"},
                {"name": "rdata_o", "width": "FE_DATA_W"},
                {"name": "ack_o", "width": 1},
                {"name": "req_reg_i", "width": 1},
                {"name": "addr_reg_i", "width": "ADDR_REG_W"},
                {"name": "wdata_reg_i", "width": "FE_DATA_W"},
                {"name": "wstrb_reg_i", "width": "FE_NBYTES"},
            ],
        },
        {
            "name": "be_write_io",
            "descr": "Back-end write channel",
            "signals": [
                {"name": "write_req_o", "width": 1},
                {
                    "name": "write_addr_o",
                    "width": "FE_ADDR_W - (FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W)",
                },
                {
                    "name": "write_wdata_o",
                    "width": "FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)",
                },
                {"name": "write_wstrb_o", "width": "FE_NBYTES"},
                {"name": "write_ack_i", "width": 1},
            ],
        },
        {
            "name": "be_read_io",
            "descr": "Back-end read channel",
            "signals": [
                {"name": "replace_req_o", "width": 1},
                {"name": "replace_i", "width": 1},
                {
                    "name": "replace_addr_o",
                    "width": "FE_ADDR_W-(BE_NBYTES_W+LINE2BE_W)",
                },
                {"name": "read_req_i", "width": 1},
                {"name": "read_addr_i", "width": "LINE2BE_W"},
                {"name": "read_rdata_i", "width": "BE_DATA_W"},
            ],
        },
        {
            "name": "ctrl_io",
            "descr": "",
            "signals": [
                {"name": "invalidate_i", "width": 1},
                {"name": "wtbuf_full_o", "width": 1},
                {"name": "wtbuf_empty_o", "width": 1},
                {"name": "write_hit_o", "width": 1},
                {"name": "write_miss_o", "width": 1},
                {"name": "read_hit_o", "width": 1},
                {"name": "read_miss_o", "width": 1},
            ],
        },
    ]
    #
    # Wires
    #
    attributes_dict["wires"] = []
    #
    # Subblocks
    #
    attributes_dict["subblocks"] = [
        {
            "core_name": "iob_ram_t2p",
            "instance_name": "iob_ram_t2p_inst",
        },
        {
            "core_name": "iob_fifo_sync",
            "instance_name": "iob_fifo_sync_inst",
        },
        {
            "core_name": "iob_ram_sp",
            "instance_name": "iob_ram_sp_inst",
        },
        # For iob_cache_replacement_policy.v
        {
            "core_name": "iob_regarray_sp",
            "instance_name": "iob_regarray_sp_inst",
        },
    ]
    #
    # Snippets
    #
    attributes_dict["snippets"] = []

    return attributes_dict
