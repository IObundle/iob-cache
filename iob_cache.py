#!/usr/bin/env python3

import os
import sys

from iob_module import iob_module
from setup import setup

# Submodules
from iob_lib import iob_lib
from iob_utils import iob_utils
from iob_regfile_sp import iob_regfile_sp
from iob_fifo_sync import iob_fifo_sync
from iob_ram_2p import iob_ram_2p
from iob_ram_sp import iob_ram_sp
from iob_reg import iob_reg
from iob_ram_sp_be import iob_ram_sp_be
from iob_tasks import iob_tasks
from iob_reg_e import iob_reg_e
from iob_prio_enc import iob_prio_enc


class iob_cache(iob_module):
    name = "iob_cache"
    version = "V0.10"
    flows = "emb sim doc fpga"
    setup_dir = os.path.dirname(__file__)

    @classmethod
    def _run_setup(cls):
        # clock, enable and reset
        iob_module.generate("iob_clk_en_rst_port"),
        iob_module.generate("iob_clk_en_rst_portmap"),
        
        # front-end port for top level and cache modules
        iob_module.generate(
            {
                "file_prefix": "fe_",
                "interface": "iob_s_port",
                "wire_prefix": "fe_",
                "port_prefix": "fe_",
                "param_prefix": "FE_",
            }
        )
        # back-end port for top level and back-end modules
        iob_module.generate(
            {
                "file_prefix": "be_",
                "interface": "iob_m_port",
                "wire_prefix": "be_",
                "port_prefix": "be_",
                "param_prefix": "FE_",
            }
        )

        # front-end portmap for top level and cache modules
        iob_module.generate(
            {
                "file_prefix": "fe_",
                "interface": "iob_s_s_portmap",
                "wire_prefix": "fe_",
                "port_prefix": "fe_",
            }
        )

        # back-end portmap for top level and back-end modules
        iob_module.generate(
            {
                "file_prefix": "be_",
                "interface": "iob_m_m_portmap",
                "wire_prefix": "be_",
                "port_prefix": "be_",
            }
        )


        # back-end master port for cache module
        iob_module.generate(
            {
                "file_prefix": "be_",
                "interface": "iob_m_port",
                "wire_prefix": "be_",
                "port_prefix": "be_",
                "param_prefix": "FE_",
            }
        )

        # back-end master portmap for cache module
        iob_module.generate(
            {
                "file_prefix": "be_",
                "interface": "iob_m_portmap",
                "wire_prefix": "be_",
                "port_prefix": "be_",
            }
        )

        # back-end wire for connecting cache module and back-end module
        iob_module.generate(
            {
                "file_prefix": "be_",
                "interface": "iob_wire",
                "wire_prefix": "be_",
                "port_prefix": "be_",
            }
        )

        # back-end slave port for backend module
        iob_module.generate(
            {
                "file_prefix": "be_",
                "interface": "iob_s_port",
                "wire_prefix": "be_",
                "port_prefix": "be_",
                "param_prefix": "BE_",
            }
        )


        # back-end slave portmap for backend module
        iob_module.generate(
            {
                "file_prefix": "be_",
                "interface": "iob_s_portmap",
                "wire_prefix": "be_",
                "port_prefix": "be_",
            }
        )


        # Utils header
        iob_utils.setup()

        # hardware modules used
        iob_regfile_sp.setup()
        iob_fifo_sync.setup()
        #iob_reg_e.setup()

        # Simulation snippets
        iob_ram_2p.setup(purpose="simulation")
        iob_ram_sp.setup(purpose="simulation")
        iob_ram_sp_be.setup(purpose="simulation")
        iob_tasks.setup(purpose="simulation")
        iob_module.generate("iob_m_tb_wire")
        iob_module.generate("iob_s_s_portmap")
        

        # TODO: will be done by iob_module
        cls._setup_confs()
        cls._setup_ios()
        cls._setup_regs()
        cls._setup_block_groups()

        # Copy sources of this module to the build directory
        super()._run_setup()

        # Setup core using LIB function
        # TODO: this should be done by iob_module
        # Thiis function will become an iob_module method
        setup(cls)

    @classmethod
    def _setup_confs(cls):
        super()._setup_confs(
            [
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
        )

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
    def _setup_block_groups(cls):
        cls.block_groups += []

    @classmethod
    def _copy_srcs(cls):
        super()._copy_srcs()
