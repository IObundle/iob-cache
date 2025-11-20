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

// print n dots (.), keep CPU busy to wait for cache
void wait_print(uint32_t n) {
  uint32_t i = 0;
  printf("\tWait Print:");
  for (i = 0; i < n; i++) {
    printf(".");
  }
  printf("\n");
}

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

int data_test() {
  uint32_t failed = 0;
  uint32_t rdata = 0;
  uint32_t wdata[3] = {0, 0xFFFFFFFF, 0};
  uint32_t ndata = 3;
  uint32_t i;

  // write data
  for (i = 0; i < ndata; i++) {
    iob_write(i * 4, DATA_W, wdata[i]);
  }

  wait_print(50);

  // read data
  for (i = 0; i < ndata; i++) {
    rdata = iob_read(i * 4, DATA_W);
    if (rdata != wdata[i]) {
      failed++;
      printf("DATA TEST ERROR at address %d: got 0x%x, expected 0x%x\n", i * 4,
             rdata, wdata[i]);
    }
  }
  return failed;
}

int address_test() {
  uint32_t failed = 0;
  uint32_t addr_w = IOB_CACHE_CSRS_FE_ADDR_W;
  uint32_t rdata = 0;
  uint32_t wdata[3] = {0x0F, 0x10, 0x0F};
  uint32_t addr[3] = {0};
  uint32_t ndata = 3;
  uint32_t i;
  uint32_t max_addr = (1 << addr_w) - 1;
  addr[1] = max_addr;

  // write data
  // write data
  for (i = 0; i < ndata; i++) {
    iob_write(addr[i], DATA_W, wdata[i]);
  }
  wait_print(50);
  // read data
  for (i = 0; i < ndata; i++) {
    rdata = iob_read(addr[i], DATA_W);
    if (rdata != wdata[i]) {
      failed++;
      printf("ADDRESS TEST ERROR at address %d: got 0x%x, expected 0x%x\n",
             addr[i], rdata, wdata[i]);
    }
  }
  return failed;
}

int lru_test(uint32_t nways_w, uint32_t nlines_w) {
  uint32_t i = 0;
  uint32_t nways = (1 << nways_w);
  uint32_t addr_step = ((1 << nlines_w) * (DATA_W / 8));
  uint32_t addr = 0;
  for (i = 0, addr = 0; i < (2 * nways); i++, addr += addr_step) {
    printf("\tLRU: mem[%x] = %x\n", addr, iob_read(addr, DATA_W));
  }
  return 0;
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

  failed += data_test();
  failed += address_test();

  failed += lru_test(IOB_CACHE_CSRS_NWAYS_W, IOB_CACHE_CSRS_NLINES_W);

  printf("CACHE test complete.\n");
  return failed;
}
