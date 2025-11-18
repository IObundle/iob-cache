/*
 * SPDX-FileCopyrightText: 2025 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

#include "iob_cache_csrs.h"
#include "iob_cache_csrs_conf.h"

#include <stdint.h>
#include <stdio.h>

#define CACHE_CTRL_BASE (1 << (IOB_CACHE_CSRS_FE_ADDR_W - 1))
#define DATA_W (IOB_CACHE_CSRS_FE_DATA_W)

int simple_test(uint32_t n) {
  uint32_t i = 0;
  uint32_t failed = 0;
  uint32_t rdata = 0;
  uint32_t expected = 0;
  // write n words to cache
  for (i = 0; i < n * 4; i += 4) {
    iob_write(i, DATA_W, (3 * i));
  }
  // read n words back
  for (i = 0; i < n * 4; i += 4) {
    rdata = iob_read(i, DATA_W);
    // check for valid data
    expected = 3 * i;
    if (rdata != expected) {
      failed++;
      printf("ERROR at address %d: got 0x%x, expected 0x%x\n", i, rdata,
             expected);
    }
  }
  return failed;
}

int iob_core_tb() {

  int failed = 0;

  // print welcome message
  printf("IOB CACHE testbench\n");

  // print the reset message
  printf("Reset complete\n");

  // init Cache Control
  iob_cache_csrs_init_baseaddr(CACHE_CTRL_BASE);

  // simple cache access test
  failed += simple_test(5);

  printf("CACHE test complete.\n");
  return failed;
}
