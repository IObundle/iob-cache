#!/usr/bin/env python3

import os
import sys

from iob_module import iob_module
from iob_block_group import iob_block_group

# Submodules
from iob_utils import iob_utils
from iob_regfile_sp import iob_regfile_sp
from iob_fifo_sync import iob_fifo_sync
from iob_ram_2p import iob_ram_2p
from iob_ram_sp import iob_ram_sp
from iob_reg import iob_reg
from iob_ram_sp_be import iob_ram_sp_be
from iob_reg_e import iob_reg_e
from iob_prio_enc import iob_prio_enc

from iob_tasks import iob_tasks


class iob_cache(iob_module):
    name = "iob_cache"
    version = "V0.10"
    flows = "emb sim doc fpga"
    setup_dir = os.path.dirname(__file__)

    @classmethod
    def _init_attributes(cls):
        super()._init_attributes()

    @classmethod
    def _create_submodules_list(cls, extra_submodules=[]):
        submodules_list = extra_submodules
        submodules_list += [
            # hardware interfaces, headers and modules
            {"interface": "clk_en_rst_port"},
            {"interface": "clk_en_rst_portmap"},
            # front-end slave port for top level and cache modules
            {"interface": "iob_s_port", "file_prefix": "fe_", "port_prefix": "fe_"},
            # front-end slave portmap for top level and cache modules
            {
                "interface": "iob_s_s_portmap",
                "file_prefix": "fe_",
                "port_prefix": "fe_",
                "wire_prefix": "fe_",
            },
            # back-end master port for top level and back-end modules
            {"interface": "iob_m_port", "file_prefix": "be_", "port_prefix": "be_"},
            # back-end master portmap for top level and back-end modules
            {
                "interface": "iob_m_m_portmap",
                "file_prefix": "be_",
                "port_prefix": "be_",
                "wire_prefix": "be_",
            },
            # back-end wire for connecting cache module and back-end module
            {"interface": "iob_wire", "file_prefix": "be_", "wire_prefix": "be_"},
            # back-end slave port for backend module
            {"interface": "iob_s_port", "file_prefix": "be_", "port_prefix": "be_"},
            # back-end slave portmap for backend module
            {
                "interface": "iob_s_portmap",
                "file_prefix": "be_",
                "port_prefix": "be_",
                "wire_prefix": "be_",
            },
            iob_utils,
            iob_regfile_sp,
            iob_fifo_sync,
            # simulation specific interfaces, headers and modules
            # control interface driver
            ({"interface": "iob_m_tb_wire"}, {"purpose": "simulation"}),
            # front-end interface driver
            (
                {
                    "interface": "iob_m_tb_wire",
                    "file_prefix": "fe_",
                    "wire_prefix": "fe_",
                },
                {"purpose": "simulation"},
            ),
            (iob_tasks, {"purpose": "simulation"}),
            (iob_ram_2p, {"purpose": "simulation"}),
            (iob_ram_sp, {"purpose": "simulation"}),
            (iob_ram_sp_be, {"purpose": "simulation"}),
        ]
        super()._create_submodules_list(submodules_list)

    @classmethod
    def _setup_confs(cls):
        _confs = [
            # control interface
            {
                "name": "ADDR_W",
                "type": "F",
                "val": "`IOB_CACHE_SWREG_ADDR_W",
                "min": "NA",
                "max": "NA",
                "descr": "Address width used by the CSR interface.",
            },
            {
                "name": "DATA_W",
                "type": "F",
                "val": "32",
                "min": "NA",
                "max": "NA",
                "descr": "Data width used by the CSR interface.",
            },
            {
                "name": "NBYTES",
                "type": "F",
                "val": "FE_DATA_W/8",
                "min": "NA",
                "max": "NA",
                "descr": "Number of bytes in a data word.",
            },
            # front-end interface
            {
                "name": "FE_ADDR_W",
                "type": "P",
                "val": "24",
                "min": "1",
                "max": "64",
                "descr": "Address width of the front-end interface.",
            },
            {
                "name": "FE_DATA_W",
                "type": "F",
                "val": "DATA_W",
                "min": "NA",
                "max": "NA",
                "descr": "Front-end data width (log2).",
            },
            {
                "name": "FE_NBYTES",
                "type": "F",
                "val": "FE_DATA_W/8",
                "min": "NA",
                "max": "NA",
                "descr": "Number of bytes in a data word.",
            },
            # back-end interface
            {
                "name": "BE_RATIO_W",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "5",
                "descr": "Ratio between the cache block size and back-end data width (log2).",
            },
            {
                "name": "BE_DATA_W",
                "type": "F",
                "val": "(2**(NWORDS_W-BE_RATIO_W))*DATA_W",
                "min": "NA",
                "max": "NA",
                "descr": "Back-end data width (log2).",
            },
            {
                "name": "BE_ADDR_W",
                "type": "F",
                "val": "FE_ADDR_W - (NWORDS_W - BE_RATIO_W)",
                "min": "NA",
                "max": "NA",
                "descr": "Back-end address width (log2).",
            },
            # Cache parameters
            {
                "name": "NWAYS_W",
                "type": "P",
                "val": "1",
                "min": "0",
                "max": "8",
                "descr": "Number of cache ways (log2).",
            },
            {
                "name": "NLINES_W",
                "type": "P",
                "val": "7",
                "min": "",
                "max": "",
                "descr": "Number of cache lines (log2).",
            },
            {
                "name": "NWORDS_W",
                "type": "P",
                "val": "3",
                "min": "0",
                "max": "",
                "descr": "Number of words per cache line (log2).",
            },
            {
                "name": "NWAYS",
                "type": "F",
                "val": "2**NWAYS_W",
                "min": "0",
                "max": "8",
                "descr": "Number of cache ways.",
            },
            {
                "name": "TAG_W",
                "type": "F",
                "val": "FE_ADDR_W - NLINES_W - NWORDS_W",
                "min": "NA",
                "max": "NA",
                "descr": "Tag width.",
            },
            {
                "name": "LINE_W",
                "type": "F",
                "val": "(2**NWORDS_W)*FE_DATA_W",
                "min": "NA",
                "max": "NA",
                "descr": "Line width.",
            },
            {
                "name": "DMEM_DATA_W",
                "type": "F",
                "val": "(2**NWAYS_W)*LINE_W",
                "min": "NA",
                "max": "NA",
                "descr": "Data width of the data memory (log2).",
            },
            {
                "name": "TAGMEM_DATA_W",
                "type": "F",
                "val": "(2**NWAYS_W)*TAG_W",
                "min": "NA",
                "max": "NA",
                "descr": "Data width of the tag memory (log2).",
            },
            # Replacement policy
            {
                "name": "REPLACE_POL",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "3",
                "descr": "Replacement policy: 0: LRU, 1: FIFO, 2: Random, 3: PLRU.",
            },
            {
                "name": "LRU",
                "type": "M",
                "val": "0",
                "min": "?",
                "max": "?",
                "descr": "Least Recently Used",
            },
            {
                "name": "PLRU_MRU",
                "type": "M",
                "val": "1",
                "min": "?",
                "max": "?",
                "descr": "Pseudo Least Recently Used (Most Recently Used)",
            },
            {
                "name": "PLRU_TREE",
                "type": "M",
                "val": "2",
                "min": "?",
                "max": "?",
                "descr": "Pseudo Least Recently Used (Tree)",
            },
            # Write Policy
            {
                "name": "WRITE_POL",
                "type": "P",
                "val": "0 ",
                "min": "0",
                "max": "1",
                "descr": "Write policy: 0: Write-through, 1: Write-back.",
            },
            {
                "name": "WRITE_THROUGH",
                "type": "M",
                "val": "0",
                "min": "NA",
                "max": "NA",
                "descr": "Write-through",
            },
            {
                "name": "WTB_DATA_W",
                "type": "F",
                "val": "BE_ADDR_W + FE_DATA_W + FE_NBYTES",
                "min": "NA",
                "max": "NA",
                "descr": "Write-through buffer data width (log2).",
            },
            {
                "name": "WTB_DEPTH_W",
                "type": "P",
                "val": "4",
                "min": "1",
                "max": "NA",
                "descr": "Write-through buffer depth (log2).",
            },
            {
                "name": "WRITE_BACK",
                "type": "M",
                "val": "1",
                "min": "NA",
                "max": "NA",
                "descr": "Write-back",
            },
        ]
        super()._setup_confs(_confs)

    @classmethod
    def _setup_regs(cls):
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
                        "addr": -1,
                        "log2n_items": 0,
                        "autologic": True,
                        "descr": "Write-through buffer empty (1) or non-empty (0).",
                    },
                    {
                        "name": "WTB_FULL",
                        "type": "R",
                        "n_bits": 1,
                        "rst_val": 0,
                        "addr": -1,
                        "log2n_items": 0,
                        "autologic": True,
                        "descr": "Write-through buffer full (1) or non-full (0).",
                    },
                    {
                        "name": "WTB_LEVEL",
                        "type": "R",
                        "n_bits": 8,
                        "rst_val": 5,
                        "addr": -1,
                        "log2n_items": 0,
                        "autologic": True,
                        "descr": "Write-through buffer level.",
                    },
                    {
                        "name": "READ_HIT_CNT",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": -1,
                        "log2n_items": 0,
                        "autologic": True,
                        "descr": "Read hit counter.",
                    },
                    {
                        "name": "READ_MISS_CNT",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": -1,
                        "log2n_items": 0,
                        "autologic": True,
                        "descr": "Read miss counter.",
                    },
                    {
                        "name": "WRITE_HIT_CNT",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": -1,
                        "log2n_items": 0,
                        "autologic": True,
                        "descr": "Write hit counter.",
                    },
                    {
                        "name": "WRITE_MISS_CNT",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": -1,
                        "log2n_items": 0,
                        "autologic": True,
                        "descr": "Write miss counter.",
                    },
                    {
                        "name": "RESET_COUNTERS",
                        "type": "W",
                        "n_bits": 1,
                        "rst_val": 0,
                        "addr": -1,
                        "log2n_items": 0,
                        "autologic": True,
                        "descr": "Reset read/write hit/miss counters by writing any value to this register.",
                    },
                    {
                        "name": "INVALIDATE",
                        "type": "W",
                        "n_bits": 1,
                        "rst_val": 0,
                        "addr": -1,
                        "log2n_items": 0,
                        "autologic": True,
                        "descr": "Invalidate the cache data contents by writing any value to this register.",
                    },
                ],
            }
        ]

    @classmethod
    def _setup_ios(cls):
        cls.ios += [
            {
                "name": "iob_clk_en_rst",
                "descr": "Clock, clock enable and asynchronous reset interface.",
                "ports": [],
            },
            {
                "name": "iob_s_port",
                "descr": "IOb Control and Status Registers Interface.",
                "ports": [],
            },
            {
                "name": "fe_iob_s_port",
                "descr": "IOb data front-end interface",
                "ports": [],
            },
            {
                "name": "be_iob_s_port",
                "descr": "IOb data back-end interface",
                "ports": [],
            },
            {
                "name": "wtb_mem",
                "descr": "Write-through buffer memory interface",
                "ports": [
                    {
                        "name": "wtb_mem_w_addr_o",
                        "type": "O",
                        "n_bits": "WTB_DEPTH_W",
                        "descr": "Write through buffer memory write address.",
                    },
                    {
                        "name": "wtb_mem_w_data_o",
                        "type": "O",
                        "n_bits": "FE_ADDR_W+FE_DATA_W+FE_NBYTES",
                        "descr": "Write through buffer memory write data.",
                    },
                    {
                        "name": "wtb_mem_w_en_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Write through buffer memory write enable.",
                    },
                    {
                        "name": "wtb_mem_r_en_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Write through buffer memory read enable.",
                    },
                    {
                        "name": "wtb_mem_r_data_i",
                        "type": "I",
                        "n_bits": "FE_ADDR_W+FE_DATA_W+FE_NBYTES",
                        "descr": "Write through buffer memory read data.",
                    },
                    {
                        "name": "wtb_mem_r_addr_o",
                        "type": "O",
                        "n_bits": "WTB_DEPTH_W",
                        "descr": "Write through buffer memory read address.",
                    },
                ],
            },
            {
                "name": "data_mem",
                "descr": "Data memory interface",
                "ports": [
                    {
                        "name": "data_mem_addr_o",
                        "type": "O",
                        "n_bits": "NLINES_W",
                        "descr": "Data memory write address.",
                    },
                    {
                        "name": "data_mem_d_o",
                        "type": "O",
                        "n_bits": "(2**NWAYS_W)*DATA_W",
                        "descr": "Data memory write data.",
                    },
                    {
                        "name": "data_mem_we_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Data memory write enable.",
                    },
                    {
                        "name": "data_mem_en_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Data memory read enable.",
                    },
                    {
                        "name": "data_mem_d_i",
                        "type": "I",
                        "n_bits": "2**NWAYS_W*DATA_W",
                        "descr": "Data memory read data.",
                    },
                ],
            },
            {
                "name": "tag_mem",
                "descr": "Data memory interface",
                "ports": [
                    {
                        "name": "tag_mem_addr_o",
                        "type": "O",
                        "n_bits": "NLINES_W",
                        "descr": "Data memory write address.",
                    },
                    {
                        "name": "tag_mem_d_o",
                        "type": "O",
                        "n_bits": "(2**NWAYS_W)*TAG_W",
                        "descr": "Data memory write data.",
                    },
                    {
                        "name": "tag_mem_we_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Data memory write enable.",
                    },
                    {
                        "name": "tag_mem_en_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Data memory read enable.",
                    },
                    {
                        "name": "tag_mem_d_i",
                        "type": "I",
                        "n_bits": "(2**NWAYS_W)*TAG_W",
                        "descr": "Data memory read data.",
                    },
                ],
            },
        ]

    @classmethod
    def _setup_block_groups(cls):
        cls.block_groups += []
