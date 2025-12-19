# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

# This makefile segment is used at build-time in $(DOC_DIR)/Makefile

#Set ASICSYNTH to 1 to include an ASIC synthesis section
ASICSYNTH=

#default ASIC node
ASIC_NODE=

#Set FPGACOMP to 1 to include an FPGA compilation section
FPGACOMP=

# include Intel FPGA results
INTEL_FPGA=

# include Intel FPGA results
AMD_FPGA=

# include UMAC130 FPGA results
UMC130_ASIC=

#Set DOXYGEN to 1 to include software documentation section from Doxygen
DOXYGEN?=1

# Select if doc is confidential
CONFIDENTIAL=0

