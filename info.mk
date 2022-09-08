# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This make segment is used at setup-time by ./Makefile
# and at build-time by iob_cache_<version>/Makefile
#

# core name
NAME=iob_cache

# core version 
VERSION=0010

# top-level module for IOB backend interface
TOP_MODULE?=iob_cache_iob

# top-level module for AXI4 backend interface
#TOP_MODULE?=iob_cache_axi

# root directory
CACHE_DIR ?= .

# supported simulator 
SIMULATOR ?= icarus

# supported FPGA board (compiles for the device therein)
# this component needs to be integrated in a system to actually run
BOARD ?= CYCLONEV-GT-DK

