# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This make segment is used at setup-time by ./Makefile
# and at build-time by iob_cache_<version>/Makefile
#

# core name
NAME=iob_cache

# core version 
VERSION=0010

# root directory when building locally
CACHE_DIR ?= .

# default configuration
CONFIG ?= iob

# supported flows
FLOWS := sim fpga doc
