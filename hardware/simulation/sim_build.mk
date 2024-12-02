# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT

#verilator top module
VTOP:=iob_cache_tb

ifeq ($(SIMULATOR),verilator)
VHDR+=iob_cache_tb.cpp
VTOP:=iob_cache_sim_wrapper
endif

iob_cache_tb.cpp: ./src/iob_cache_tb.cpp
	cp $< $@
