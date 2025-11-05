# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params: dict):
    # Create dictionary with attributes of cache
    attributes_dict = {
        "generate_hw": True,
    }
    #
    # Confs
    #
    attributes_dict["confs"] = [
        # Currently, Py2hwsw does not have a way of adding `includes. So we need to repeat this CSRs ADDR_W macro manually here
        {
            "name": "ADDR_W_CSRS",
            "descr": "Address width of CSRs",
            "type": "M",
            "val": "5",
            "min": "?",
            "max": "?",
        },
        {
            "name": "ADDR_W",
            "descr": "Cache address width used by csrs_gen",
            "type": "P",
            "val": "`IOB_CACHE_FRONT_END_ADDR_W_CSRS",
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
                {"name": "ctrl_addr_o", "width": "`IOB_CACHE_FRONT_END_ADDR_W_CSRS"},
                {"name": "ctrl_rdata_i", "width": "USE_CTRL*(DATA_W-1)+1"},
                {"name": "ctrl_ack_i", "width": 1},
            ],
        },
    ]
    #
    # Wires
    #
    attributes_dict["wires"] = [
        {
            "name": "internal_wires",
            "descr": "Internal wires",
            "signals": [
                {"name": "ack", "width": 1},
                {"name": "valid_int", "width": 1},
                {"name": "we_r", "width": 1},
            ],
        },
    ]
    #
    # Combinatorial
    #
    attributes_dict["comb"] = {
        "code": """
        // data output ports
        data_addr_o  = valid_int ? iob_addr_i[ADDR_W-USE_CTRL-1:0] : data_addr_reg_o;
        data_req_o   = valid_int | data_req_reg_o;

        iob_rvalid_o = we_r ? 1'b0 : ack;
        iob_ready_o  = data_req_reg_o ~^ ack;

        // Register every input
        data_req_reg_o_nxt = valid_int;
        data_req_reg_o_en = valid_int | ack;

        data_addr_reg_o_nxt = iob_addr_i[ADDR_W-USE_CTRL-1:0];
        data_addr_reg_o_en = valid_int;

        data_wdata_reg_o_nxt = iob_wdata_i;
        data_wdata_reg_o_en = valid_int;

        data_wstrb_reg_o_nxt = iob_wstrb_i;
        data_wstrb_reg_o_en = valid_int;

        we_r_nxt = |iob_wstrb_i;
        we_r_en = valid_int;
"""
    }
    #
    # Snippets
    #
    attributes_dict["snippets"] = [
        {
            "verilog_code": """
   // select cache memory or controller
   generate
      if (USE_CTRL) begin : g_ctrl
         // Front-end output signals
         assign ack         = ctrl_ack_i | data_ack_i;
         assign iob_rdata_o = (ctrl_ack_i) ? ctrl_rdata_i : data_rdata_i;

         assign valid_int   = ~iob_addr_i[ADDR_W-1] & iob_valid_i;

         assign ctrl_req_o  = iob_addr_i[ADDR_W-1] & iob_valid_i;
         assign ctrl_addr_o = iob_addr_i[`IOB_CACHE_FRONT_END_ADDR_W_CSRS-1:0];

      end else begin : g_no_ctrl
         // Front-end output signals
         assign ack         = data_ack_i;
         assign iob_rdata_o = data_rdata_i;
         assign valid_int   = iob_valid_i;
         assign ctrl_req_o  = 1'b0;
         assign ctrl_addr_o = `IOB_CACHE_FRONT_END_ADDR_W_CSRS'dx;
      end
   endgenerate
""",
        },
    ]

    return attributes_dict
