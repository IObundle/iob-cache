# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT

#verilator top module
VTOP:=iob_cache_tb

# Custom Coverage Analysis
CUSTOM_COVERAGE_FLAGS=cov_annotated
CUSTOM_COVERAGE_FLAGS+=-E iob_cache_tb.v
CUSTOM_COVERAGE_FLAGS+=-E iob_uut.v
CUSTOM_COVERAGE_FLAGS+=--waive cache_coverage.waiver
CUSTOM_COVERAGE_FLAGS+=--waived-tag
CUSTOM_COVERAGE_FLAGS+=-o cache_coverage.rpt
