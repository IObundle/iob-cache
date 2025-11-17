# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT

import os
from pathlib import Path
import shutil


def setup(py_params: dict):

    be_if = py_params.get("be_if", "axi")

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
                {"name": "addr_i", "width": f"`IOB_CACHE_{be_if.upper()}_CSRS_ADDR_W"},
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

    # Copy correct iob_cache_control according to cache backend interface
    # Backend interface type ["axi", "iob"]
    hw_src = os.path.dirname(os.path.realpath(__file__))
    hw_src = f"{hw_src}/hardware/{be_if}/iob_cache_control_{be_if}.v"
    hw_dst = f"{py_params['build_dir']}/hardware/src/"
    Path(hw_dst).mkdir(parents=True, exist_ok=True)
    shutil.copy2(hw_src, f"{hw_dst}/iob_cache_control.v")

    return attributes_dict
