# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This make segment is used at setup-time by ./Makefile
# and at build-time by iob_cache_<version>/Makefile
#

# core name
NAME=iob_cache

# core version 
VERSION=0010

# include implementation in document (disabled by default)
DOC_RESULTS=

# root directory when building locally
CACHE_DIR ?= .

# default configuration
CONFIG ?= iob
