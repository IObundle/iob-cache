#!/usr/bin/env python3

import os
import sys

from iob_module import iob_module
from setup import setup

# Submodules
from iob_lib import iob_lib
from iob_utils import iob_utils

from iob_clkenrst_port import iob_clkenrst_port
from iob_clkenrst_portmap import iob_clkenrst_portmap

from iob_regfile_sp import iob_regfile_sp
from iob_fifo_sync import iob_fifo_sync
from iob_ram_2p import iob_ram_2p
from iob_ram_sp import iob_ram_sp
from iob_reg import iob_reg
from iob_ram_sp_be import iob_ram_sp_be
from iob_tasks import iob_tasks
from iob_reg_e import iob_reg_e


class iob_cache(iob_module):
    name = "iob_cache"
    version = "V0.10"
    flows = "emb sim doc fpga"
    setup_dir = os.path.dirname(__file__)

    # Public method to set dynamic attributes
    # This method is automatically called by the `setup` method
    @classmethod
    def set_dynamic_attributes(cls):
        super().set_dynamic_attributes()

        # Parse BE_DATA_W argument
        cls.BE_DATA_W = "32"
        for arg in sys.argv[1:]:
            if "BE_DATA_W" in arg:
                cls.BE_DATA_W = arg.split("=")[1]
                if cls.BE_DATA_W not in ["32", "64", "128", "256"]:
                    print("ERROR: backend interface width must be 32, 64, 128 or 256")
                    exit(1)

        # Parse BE_IF argument
        cls.BE_IF = "IOb"
        for arg in sys.argv[1:]:
            if "BE_IF" in arg:
                cls.BE_IF = arg.split("=")[1]
                if cls.BE_IF not in ["AXI4", "IOb"]:
                    print("ERROR: backend interface must be either AXI4 or IOb")
                    exit(1)

        cls.AXI_CONFS = []
        if cls.BE_IF == "AXI4":
            cls.AXI_CONFS = [
                {
                    "name": "AXI",
                    "type": "M",
                    "val": "NA",
                    "min": "NA",
                    "max": "NA",
                    "descr": "AXI interface used by backend",
                },
                {
                    "name": "AXI_ID_W",
                    "type": "M",
                    "val": "1",
                    "min": "?",
                    "max": "?",
                    "descr": "description",
                },
                {
                    "name": "AXI_LEN_W",
                    "type": "M",
                    "val": "4",
                    "min": "?",
                    "max": "?",
                    "descr": "description",
                },
                {
                    "name": "AXI_ID",
                    "type": "M",
                    "val": "0",
                    "min": "?",
                    "max": "?",
                    "descr": "description",
                },
            ]

    @classmethod
    def _run_setup(cls):
        # Hardware modules and snippets

        # iob control interface
        iob_module.generate("iob_s_port")

        if cls.BE_IF == "IOb":
            iob_module.generate("iob_wire")
            # Simulation modules & snippets
            iob_module.generate("iob_m_tb_wire")
            iob_module.generate("iob_s_s_portmap")
            iob_module.generate(
                {
                    "file_prefix": "fe_",
                    "interface": "iob_s_s_portmap",
                    "wire_prefix": "fe_",
                    "port_prefix": "fe_",
                }
            )
            iob_module.generate(
                {
                    "file_prefix": "int_",
                    "interface": "iob_m_portmap",
                    "wire_prefix": "int_",
                    "port_prefix": "int_",
                }
            )
            iob_module.generate(
                {
                    "file_prefix": "int_",
                    "interface": "iob_s_portmap",
                    "wire_prefix": "int_",
                    "port_prefix": "int_",
                }
            )
            iob_module.generate(
                {
                    "file_prefix": "be_",
                    "interface": "iob_m_m_portmap",
                    "wire_prefix": "be_",
                    "port_prefix": "be_",
                }
            )
            iob_ram_sp_be.setup(purpose="hardware")
            iob_tasks.setup(purpose="simulation")

        if cls.BE_IF == "AXI4":
            # axi backend interface
            iob_module.generate("axi_m_port")
            # axi portmap for internal backend module
            iob_module.generate("axi_m_m_portmap")

            # internal axi backend module headers
            iob_module.generate("axi_m_write_port")
            iob_module.generate("axi_m_read_port")
            iob_module.generate("axi_m_m_write_portmap")
            iob_module.generate("axi_m_m_read_portmap")
            # Simulation modules & snippets
            iob_module.generate("axi_s_portmap")
            iob_module.generate("axi_wire", purpose="simulation")

        iob_utils.setup()

        iob_clkenrst_port.setup()
        iob_clkenrst_portmap.setup()
        iob_regfile_sp.setup()
        iob_fifo_sync.setup()
        iob_ram_2p.setup()
        iob_ram_sp.setup()
        iob_reg.setup()
        iob_reg_e.setup()

        # Verilog modules instances
        # TODO

        cls._setup_confs()
        cls._setup_ios()
        cls._setup_regs()
        cls._setup_block_groups()

        # Copy sources of this module to the build directory
        super()._run_setup()

        # Setup core using LIB function
        setup(cls)

    @classmethod
    def _setup_confs(cls):
        super()._setup_confs(
            [
                # Macros
                {
                    "name": "FE_ADDR_W",
                    "type": "P",
                    "val": "24",
                    "min": "1",
                    "max": "64",
                    "descr": "Front-end address width (log2): defines the total memory space accessible via the cache, which must be a power of two.",
                },
                {
                    "name": "BE_RATIO_W",
                    "type": "P",
                    "val": "0",
                    "min": "0",
                    "max": "5",
                    "descr": "Ratio between the front-end and back-end data widths (log2): defines the ratio between the front-end and back-end data widths, which must be a power of two.",
                },
                {
                    "name": "BE_ADDR_W",
                    "type": "F",
                    "val": "FE_ADDR_W - BE_RATIO_W",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Back-end address width (log2): defines the total memory space accessible via the backend, which must be a power of two.",
                },
                {
                    "name": "BE_DATA_W",
                    "type": "F",
                    "val": "FE_DATA_W * 2**BE_RATIO_W",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Back-end data width (log2): defines the data width of the backend.",
                },
                # Cache parameters
                {
                    "name": "NWAYS_W",
                    "type": "P",
                    "val": "1",
                    "min": "0",
                    "max": "8",
                    "descr": "Number of cache ways (log2): defines the number of ways in the cache, which must be a power of two.",
                },
                {
                    "name": "NLINES_W",
                    "type": "P",
                    "val": "7",
                    "min": "",
                    "max": "",
                    "descr": "Line offset width (log2): defines the number of bits used to address a line within the cache.",
                },
                {
                    "name": "WORD_OFFSET_W",
                    "type": "P",
                    "val": "3",
                    "min": "0",
                    "max": "",
                    "descr": "Word offset width (log2): defines the number of bits used to address a word within a cache line.",
                },
                {
                    "name": "TAG_W",
                    "type": "F",
                    "val": "FE_ADDR_W - NLINES_W - WORD_OFFSET_W",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Tag width (log2): defines the number of bits of the tag.",
                },
                {
                    "name": "WTB_MEM_ADDR_W",
                    "type": "P",
                    "val": "4",
                    "min": "",
                    "max": "",
                    "descr": "Write-through buffer depth (log2): defines the number of entries in the write-through buffer, which must be a power of two.",
                },
                # Replacement policy
                {
                    "name": "REP_POLICY",
                    "type": "P",
                    "val": "0",
                    "min": "0",
                    "max": "3",
                    "descr": "Replacement policy: defines the replacement policy used by the cache.",
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
                    "descr": "Write policy: defines the write policy used by the cache.",
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
                    "name": "WRITE_BACK",
                    "type": "M",
                    "val": "1",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Write-back",
                },
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
                    "val": "DATA_W/8",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Number of bytes in a data word.",
                },
                {
                    "name": "NBYTES_W",
                    "type": "F",
                    "val": "$clog2(NBYTES)",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Number of bytes in a data word (log2).",
                },
            ]
            + cls.AXI_CONFS
        )

    @classmethod
    def _setup_ios(cls):
        cls.ios += [
            {
                "name": "iob_s_port",
                "descr": "IOb Control and Status Registers Interface.",
                "ports": [],
            },
            {
                "name": "fe",
                "descr": "IOb data front-end interface",
                "ports": [
                    {
                        "name": "fe_iob_avalid_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "Address valid.",
                    },
                    {
                        "name": "fe_iob_addr_i",
                        "type": "I",
                        "n_bits": "FE_ADDR_W-$clog2(FE_DATA_W/8)",
                        "descr": "Address.",
                    },
                    {
                        "name": "fe_iob_wdata_i",
                        "type": "I",
                        "n_bits": "FE_DATA_W",
                        "descr": "Write data.",
                    },
                    {
                        "name": "fe_iob_wstrb_i",
                        "type": "I",
                        "n_bits": "DATA_W/8",
                        "descr": "Write strofe.",
                    },
                    {
                        "name": "fe_iob_rdata_o",
                        "type": "O",
                        "n_bits": "DATA_W",
                        "descr": "Read data.",
                    },
                    {
                        "name": "fe_iob_rvalid_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Read valid.",
                    },
                    {
                        "name": "fe_iob_ready_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Ready.",
                    },
                ],
            },
            {
                "name": "be",
                "descr": "IOb data back-end interface",
                "ports": [
                    {
                        "name": "be_iob_avalid_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Address valid.",
                    },
                    {
                        "name": "be_iob_addr_o",
                        "type": "O",
                        "n_bits": "BE_ADDR_W",
                        "descr": "Address.",
                    },
                    {
                        "name": "be_iob_wdata_o",
                        "type": "O",
                        "n_bits": "BE_DATA_W",
                        "descr": "Write data.",
                    },
                    {
                        "name": "be_iob_wstrb_o",
                        "type": "O",
                        "n_bits": "BE_DATA_W/8",
                        "descr": "Write strobe.",
                    },
                    {
                        "name": "be_iob_rdata_i",
                        "type": "I",
                        "n_bits": "BE_DATA_W",
                        "descr": "Read data.",
                    },
                    {
                        "name": "be_iob_rvalid_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "Read valid.",
                    },
                    {
                        "name": "be_iob_ready_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "Ready.",
                    },
                ],
            },
            {
                "name": "wtb_mem",
                "descr": "Write-through buffer memory interface",
                "ports": [
                    {
                        "name": "wtb_mem_w_addr_o",
                        "type": "O",
                        "n_bits": "WTB_MEM_ADDR_W",
                        "descr": "Write through buffer memory write address.",
                    },
                    {
                        "name": "wtb_mem_w_data_o",
                        "type": "O",
                        "n_bits": "FE_ADDR_W+FE_DATA_W+NBYTES",
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
                        "n_bits": "FE_ADDR_W+FE_DATA_W+NBYTES",
                        "descr": "Write through buffer memory read data.",
                    },
                    {
                        "name": "wtb_mem_r_addr_o",
                        "type": "O",
                        "n_bits": "WTB_MEM_ADDR_W",
                        "descr": "Write through buffer memory read address.",
                    },
                ],
            },
            {
                "name": "data_mem",
                "descr": "Data memory interface",
                "ports": [
                    {
                        "name": "data_mem_w_addr_o",
                        "type": "O",
                        "n_bits": "NLINES_W",
                        "descr": "Data memory write address.",
                    },
                    {
                        "name": "data_mem_w_data_o",
                        "type": "O",
                        "n_bits": "2**NWAYS_W*(TAG_W+DATA_W)",
                        "descr": "Data memory write data.",
                    },
                    {
                        "name": "data_mem_w_en_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Data memory write enable.",
                    },
                    {
                        "name": "data_mem_r_en_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Data memory read enable.",
                    },
                    {
                        "name": "data_mem_r_data_i",
                        "type": "I",
                        "n_bits": "2**NWAYS_W*(TAG_W+DATA_W)",
                        "descr": "Data memory read data.",
                    },
                ],
            },
            {
                "name": "ge",
                "descr": "General Interface Signals",
                "ports": [
                    {
                        "name": "clk_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "System clock input.",
                    },
                    {
                        "name": "cke_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "System clock enable signal.",
                    },
                    {
                        "name": "arst_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "System reset, asynchronous and active high.",
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
