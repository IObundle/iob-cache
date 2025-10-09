# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params: dict):
    # Create dictionary with attributes of cache
    attributes_dict = {
        "generate_hw": False,
    }
    #
    # Confs
    #
    attributes_dict["confs"] = [
        {
            "name": "DATA_W",
            "descr": "Data width",
            "type": "P",
            "val": "32",
            "min": "NA",
            "max": "NA",
        },
        {
            "name": "USE_CTRL_CNT",
            "descr": "Instantiates hit/miss counters for reads, writes or both (1), or not (0). This parameter is meaningful if the cache controller is present (USE_CTRL: 1), providing additional software accessible functions for these functions.",
            "type": "P",
            "val": "1",
            "min": "0",
            "max": "1",
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
                "params": "c_a",
            },
        },
        {
            "name": "cache_ctrl_io",
            "descr": "",
            "signals": [
                {"name": "valid_i", "width": 1},
                {"name": "addr_i", "width": "`IOB_CACHE_CSRS_ADDR_W"},
                {"name": "wtbuf_full_i", "width": 1},
                {"name": "wtbuf_empty_i", "width": 1},
                {"name": "write_hit_i", "width": 1},
                {"name": "write_miss_i", "width": 1},
                {"name": "read_hit_i", "width": 1},
                {"name": "read_miss_i", "width": 1},
                {"name": "rdata_o", "width": "DATA_W", "isvar": True},
                {"name": "ready_o", "width": 1, "isvar": True},
                {"name": "invalidate_o", "width": 1, "isvar": True},
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
    attributes_dict["subblocks"] = []
    #
    # Snippets
    #
    attributes_dict["snippets"] = []

    return attributes_dict
