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
            "name": "cache_mem_io",
            "descr": "Cache memory front-end interface",
            "signals": [
                {"name": "data_req_o", "width": 1},
                {"name": "data_addr_o", "width": "ADDR_W-USE_CTRL"},
                {"name": "data_rdata_i", "width": "DATA_W"},
                {"name": "data_ack_i", "width": 1},
                {"name": "data_req_reg_o", "width": 1},
                {"name": "data_addr_reg_o", "width": "ADDR_W-USE_CTRL"},
                {"name": "data_wdata_reg_o", "width": "DATA_W"},
                {"name": "data_wstrb_reg_o", "width": "DATA_W/8"},
            ],
        },
        {
            "name": "ctrl_io",
            "descr": "Control interface.",
            "signals": [
                {"name": "ctrl_req_o", "width": 1},
                {"name": "ctrl_addr_o", "width": "`IOB_CACHE_CSRS_ADDR_W"},
                {"name": "ctrl_rdata_i", "width": "USE_CTRL*(DATA_W-1)+1"},
                {"name": "ctrl_ack_i", "width": 1},
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
            "core_name": "iob_reg",
            "instance_name": "iob_reg_care_inst",
            "port_params": {
                "clk_en_rst_s": "c_a_r_e",
            },
        },
    ]
    #
    # Snippets
    #
    attributes_dict["snippets"] = []

    return attributes_dict
