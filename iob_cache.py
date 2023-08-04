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
            # back-end master portmap for top level and cache modules
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
            {
                "interface": "ram_sp_be_port",
                "file_prefix": "data_",
                "wire_prefix": "data_",
                "port_prefix": "data_",
            },
            {
                "interface": "ram_sp_be_portmap",
                "file_prefix": "data_",
                "wire_prefix": "data_",
                "port_prefix": "data_",
            },
            {
                "interface": "ram_sp_port",
                "file_prefix": "tag_",
                "wire_prefix": "tag_",
                "port_prefix": "tag_",
            },
            {
                "interface": "ram_sp_portmap",
                "file_prefix": "tag_",
                "wire_prefix": "tag_",
                "port_prefix": "tag_",
            },
            {
                "interface": "ram_2p_port",
                "file_prefix": "wtb_",
                "wire_prefix": "wtb_",
                "port_prefix": "wtb_",
            },
            {
                "interface": "ram_2p_portmap",
                "file_prefix": "wtb_",
                "wire_prefix": "wtb_",
                "port_prefix": "wtb_",
            },
            iob_utils,
            iob_reg_e,
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
            # back-end portmap for testbench
            (
                {
                    "interface": "iob_m_portmap",
                    "file_prefix": "be_",
                    "port_prefix": "be_",
                    "wire_prefix": "be_",
                },
                {"purpose": "simulation"},
            ),
            # back-end interface bus connecting cache and memory
            (
                {
                    "interface": "iob_wire",
                    "file_prefix": "be_",
                    "wire_prefix": "be_",
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
                "min": "20",
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
                "name": "BE_ADDR_W",
                "type": "F",
                "val": "(FE_ADDR_W-$clog2(BE_DATA_W/FE_DATA_W))",
                "min": "20",
                "max": "64",
                "descr": "Back-end address width (log2).",
            },
            {
                "name": "BE_DATA_W",
                "type": "P",
                "val": "64",
                "min": "NA",
                "max": "NA",
                "descr": "Back-end data width (log2).",
            },
            {
                "name": "BE_NBYTES",
                "type": "F",
                "val": "BE_DATA_W/8",
                "min": "NA",
                "max": "NA",
                "descr": "Number of bytes in a data word.",
            },
            # Cache parameters
            {
                "name": "NWAYS_W",
                "type": "P",
                "val": "1",
                "min": "0",
                "max": "8",
                "descr": "Number of ways (log2).",
            },
            {
                "name": "NWAYS",  # needed for way one hot encoding
                "type": "F",
                "val": "(2**NWAYS_W)",
                "min": "0",
                "max": "8",
                "descr": "Number of ways.",
            },
            {
                "name": "NSETS_W",
                "type": "P",
                "val": "7",
                "min": "",
                "max": "",
                "descr": "Number of sets (log2).",
            },
            {
                "name": "BLK_SIZE_W",
                "type": "P",
                "val": "3",
                "min": "0",
                "max": "8",
                "descr": "Block size (log2).",
            },
            {
                "name": "BLK_SIZE",
                "type": "F",
                "val": "(2**BLK_SIZE_W)",
                "min": "NA",
                "max": "NA",
                "descr": "Block size (log2).",
            },
            {
                "name": "TAG_W",
                "type": "F",
                "val": "(FE_ADDR_W - NSETS_W - BLK_SIZE_W)",
                "min": "NA",
                "max": "NA",
                "descr": "Tag width.",
            },
            {
                "name": "LINE_W",
                "type": "F",
                "val": "BLK_SIZE*FE_DATA_W",
                "min": "NA",
                "max": "NA",
                "descr": "Line width.",
            },
            {
                "name": "DATA_ADDR_W",
                "type": "F",
                "val": "NSETS_W",
                "min": "NA",
                "max": "NA",
                "descr": "Address width of the data memory (log2).",
            },
            {
                "name": "DATA_DATA_W",
                "type": "F",
                "val": "NWAYS*LINE_W",
                "min": "NA",
                "max": "NA",
                "descr": "Data width of the data memory (log2).",
            },
            {
                "name": "TAG_ADDR_W",
                "type": "F",
                "val": "NSETS_W",
                "min": "NA",
                "max": "NA",
                "descr": "Address width of the data memory (log2).",
            },
            {
                "name": "TAG_DATA_W",
                "type": "F",
                "val": "(NWAYS*TAG_W)",
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
                "min": "NA",
                "max": "NA",
                "descr": "Least Recently Used",
            },
            {
                "name": "PLRU_MRU",
                "type": "M",
                "val": "1",
                "min": "NA",
                "max": "NA",
                "descr": "Pseudo Least Recently Used (Most Recently Used)",
            },
            {
                "name": "PLRU_TREE",
                "type": "M",
                "val": "2",
                "min": "NA",
                "max": "NA",
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
                "val": "(BE_ADDR_W + BE_NBYTES + BE_DATA_W)",
                "min": "NA",
                "max": "NA",
                "descr": "Write-through buffer data width (log2).",
            },
            {
                "name": "WTB_ADDR_W",
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
                "name": "clk_en_rst_port",
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
                "name": "be_iob_m_port",
                "descr": "IOb data back-end interface",
                "ports": [],
            },
            {
                "name": "wtb_ram_2p_port",
                "descr": "Write Through Buffer memory interface",
                "ports": [],
            },
            {
                "name": "data_ram_sp_be_port",
                "descr": "Data memory interface",
                "ports": [],
            },
            {
                "name": "tag_ram_sp_port",
                "descr": "Data memory interface",
                "ports": [],
            },
        ]

    @classmethod
    def _setup_block_groups(cls):
        cls.block_groups += []
