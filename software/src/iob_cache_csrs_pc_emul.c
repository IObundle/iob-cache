/*
 * SPDX-FileCopyrightText: 2024 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

/* PC Emulation of CACHE peripheral */
#include "iob_cache_csrs.h"

static int base;
void IOB_CACHE_INIT_BASEADDR(uint32_t addr) { base = addr; }

// Core Setters
void IOB_CACHE_SET_RST_CNTRS(uint8_t value) { return; }

void IOB_CACHE_SET_INVALIDATE(uint8_t value) { return; }

// Core Getters
uint8_t IOB_CACHE_GET_WTB_EMPTY() { return 1; }

uint8_t IOB_CACHE_GET_WTB_FULL() { return 0; }

uint32_t IOB_CACHE_GET_RW_HIT() { return 0; }

uint32_t IOB_CACHE_GET_RW_MISS() { return 0; }

uint32_t IOB_CACHE_GET_READ_HIT() { return 0; }

uint32_t IOB_CACHE_GET_READ_MISS() { return 0; }

uint32_t IOB_CACHE_GET_WRITE_HIT() { return 0; }

uint32_t IOB_CACHE_GET_WRITE_MISS() { return 0; }

uint16_t IOB_CACHE_GET_VERSION() { return 0x0010; }
