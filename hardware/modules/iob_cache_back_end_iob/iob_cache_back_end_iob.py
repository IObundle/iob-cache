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
            "val": "32",
            "min": "32",
            "max": "256",
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
            "name": "WRITE_POL",
            "descr": "Write policy: set to 0 for write-through or set to 1 for write-back.",
            "type": "P",
            "val": "0 ",
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
            "name": "write_io",
            "descr": "Back-end write channel",
            "signals": [
                {"name": "write_valid_i", "width": 1},
                {
                    "name": "write_addr_i",
                    "width": "FE_ADDR_W - (FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W)",
                },
                {
                    "name": "write_wdata_i",
                    "width": "FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)",
                },
                {"name": "write_wstrb_i", "width": "FE_NBYTES"},
                {"name": "write_ready_o", "width": 1},
            ],
        },
        {
            "name": "read_io",
            "descr": "Back-end read channel",
            "signals": [
                {"name": "replace_valid_i", "width": 1},
                {"name": "replace_o", "width": 1},
                {
                    "name": "replace_addr_i",
                    "width": "FE_ADDR_W-(BE_NBYTES_W+LINE2BE_W)",
                },
                {"name": "read_valid_o", "width": 1},
                {"name": "read_addr_o", "width": "LINE2BE_W"},
                {"name": "read_rdata_o", "width": "AXI_DATA_W"},
            ],
        },
        {
            "name": "iob_m",
            "descr": "Back-end interface",
            "signals": {
                "type": "iob",
                "ADDR_W": "BE_ADDR_W",
                "DATA_W": "BE_DATA_W",
            },
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
