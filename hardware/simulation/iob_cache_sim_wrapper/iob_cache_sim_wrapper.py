# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params_dict):
    params = {
        # Confs passed by issuer (iob_cache)
        "cache_confs": [],
        "be_if": "axi",
    }

    # Update params with values from py_params_dict
    for param in py_params_dict:
        if param in params:
            params[param] = py_params_dict[param]

    assert params["be_if"] in ["axi", "iob"], "Invalid BE_IF"

    attributes_dict = {
        "name": "iob_uut",
        "generate_hw": True,
        "confs": params["cache_confs"],
    }
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
            "name": "cache_s",
            "descr": "Testbench cache csrs interface",
            "signals": {
                "type": "iob",
                "ADDR_W": "ADDR_W",
                "DATA_W": "DATA_W",
            },
        },
    ]
    #
    # Confs
    #
    # Overwrite Cache Confs
    for conf in attributes_dict["confs"]:
        if conf["name"] == "USE_CTRL":
            conf["val"] = "1"
        elif conf["name"] == "USE_CTRL_CNT":
            conf["val"] = "1"
    #
    # Wires
    #
    attributes_dict["wires"] = [
        {
            "name": "clk",
            "descr": "Clock signal",
            "signals": [
                {"name": "clk_i"},
            ],
        },
        {
            "name": "rst",
            "descr": "Reset signal",
            "signals": [
                {"name": "arst_i"},
            ],
        },
        {
            "name": "ie",
            "descr": "Internal signals for cache invalidate and write-trough buffer IO chain",
            "signals": [
                {"name": "invalidate_i_int", "width": 1},
                {"name": "invalidate_o_int", "width": 1},
                {"name": "wtb_empty_i_int", "width": 1},
                {"name": "wtb_empty_o_int", "width": 1},
            ],
        },
    ]
    if params["be_if"] == "axi":
        attributes_dict["wires"] += [
            {
                "name": "axi",
                "descr": "AXI bus to connect Cache back end to memory",
                "signals": {
                    "type": "axi",
                    "prefix": "be_",
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                    "LOCK_W": 1,
                },
            },
            {
                "name": "axi_ram_mem",
                "descr": "Connect axi_ram to 'iob_ram_t2p_be' memory",
                "signals": {
                    "type": "ram_t2p_be",
                    "prefix": "ext_mem_",
                    "ADDR_W": "AXI_ADDR_W - 2",
                },
            },
        ]
    elif params["be_if"] == "iob":
        attributes_dict["wires"] += [
            {
                "name": "iob",
                "descr": "IOb bus to connect Cache back end to memory",
                "signals": {
                    "type": "iob",
                    "prefix": "be_",
                    "ADDR_W": "BE_ADDR_W",
                    "DATA_W": "BE_DATA_W",
                },
            },
            {
                "name": "mem_if",
                "descr": "Memory interface",
                "signals": [
                    {"name": "mem_en_i", "width": 1},
                    {"name": "mem_we_i", "width": "BE_DATA_W/8"},
                    {"name": "mem_addr_i", "width": "BE_ADDR_W"},
                    {"name": "mem_d_i", "width": "BE_DATA_W"},
                    {"name": "mem_d_o", "width": "BE_DATA_W"},
                ],
            },
            {
                "name": "iob_reg_rvalid",
                "descr": "Register valid signal",
                "signals": [
                    {"name": "iob_reg_rvalid", "width": 1},
                ],
            },
        ]
    #
    # Blocks
    #
    attributes_dict["subblocks"] = [
        {
            "core_name": "iob_cache",
            "instance_name": "cache",
            "instance_description": f"Unit Under Test (UUT) Cache instance with '{params['be_if']}' back end interface.",
            "parameters": {
                "USE_CTRL": "USE_CTRL",
                "USE_CTRL_CNT": "USE_CTRL_CNT",
            },
            "connect": {
                "clk_en_rst_s": "clk_en_rst_s",
                "iob_s": "cache_s",
                f"{params['be_if']}_m": f"{params['be_if']}",
                "ie_io": "ie",
            },
        },
    ]
    if params["be_if"] == "axi":
        attributes_dict["subblocks"] += [
            {
                "core_name": "iob_axi_ram",
                "instance_name": "ddr_model_mem",
                "instance_description": "External memory",
                "parameters": {
                    "ID_WIDTH": "AXI_ID_W",
                    "ADDR_WIDTH": "AXI_ADDR_W",
                    "DATA_WIDTH": "AXI_DATA_W",
                    "LEN_WIDTH": "AXI_LEN_W",
                },
                "connect": {
                    "clk_i": "clk",
                    "rst_i": "rst",
                    "axi_s": (
                        "axi",
                        [
                            "{1'b0, be_axi_arlock}",
                            "{1'b0, be_axi_awlock}",
                        ],
                    ),
                    "external_mem_bus_m": "axi_ram_mem",
                },
            },
            {
                "core_name": "iob_ram_t2p_be",
                "instance_name": "iob_ram_t2p_be_inst",
                "parameters": {
                    "ADDR_W": "AXI_ADDR_W - 2",
                    "DATA_W": "AXI_DATA_W",
                },
                "connect": {
                    "ram_t2p_be_s": "axi_ram_mem",
                },
            },
        ]
    elif params["be_if"] == "iob":
        attributes_dict["subblocks"] += [
            {
                "core_name": "iob_ram_sp_be",
                "instance_name": "native_ram",
                "parameters": {
                    "ADDR_W": "BE_ADDR_W",
                    "DATA_W": "BE_DATA_W",
                },
                "connect": {
                    "clk_i": "clk",
                    "mem_if_io": "mem_if",
                },
            },
        ]
    #
    # Combinatorial
    #
    attributes_dict["snippets"] = [
        """
   // Set constant inputs and connect outputs
   assign invalidate_i_int = 1'b0;
   assign wtb_empty_i_int = 1'b1;
"""
    ]
    if params["be_if"] == "iob":
        comb_code = """
   be_iob_ready = 1'b1;

   mem_en_i = be_iob_valid;
   mem_we_i = be_iob_wstrb;
   mem_addr_i = be_iob_addr;
   mem_d_i = be_iob_wdata;
   be_iob_rdata = mem_d_o;

   iob_reg_rvalid_nxt = be_iob_valid & (~(|be_iob_wstrb));
   be_iob_rvalid = iob_reg_rvalid;
"""
        attributes_dict["comb"] = {"code": comb_code}

    return attributes_dict
