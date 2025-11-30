# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT

# Custom Coverage Analysis
CUSTOM_COVERAGE_FLAGS=cov_annotated
CUSTOM_COVERAGE_FLAGS+=-E iob_uut.v
CUSTOM_COVERAGE_FLAGS+=-E iob_ram_sp_be.v
CUSTOM_COVERAGE_FLAGS+=-E iob_reg_ca.v
CUSTOM_COVERAGE_FLAGS+=--waive cache_coverage.waiver
CUSTOM_COVERAGE_FLAGS+=--waived-tag
CUSTOM_COVERAGE_FLAGS+=-o cache_coverage.rpt
