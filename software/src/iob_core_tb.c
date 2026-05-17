/*
 * SPDX-FileCopyrightText: 2025 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

#include "iob_cache_csrs.h"
#include "iob_cache_csrs_conf.h"

#include <stdint.h>
#include <stdio.h>

#define USE_CTRL (1)
#define DATA_W (IOB_CACHE_CSRS_FE_DATA_W)
#define FE_NBYTES_W (2)
#define CACHE_DATA_ADDR_W (IOB_CACHE_CSRS_FE_ADDR_W)
// address control after data addressing
#define CACHE_CTRL_BASE (1 << (CACHE_DATA_ADDR_W))

static inline void use_ctrl() { iob_cache_csrs_init_baseaddr(CACHE_CTRL_BASE); }

static inline void use_data() { iob_cache_csrs_init_baseaddr(0); }

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
  uint32_t addr_w = CACHE_DATA_ADDR_W;
  uint32_t rdata = 0;
  uint32_t wdata[3] = {0x0F, 0x10, 0x0F};
  uint32_t addr[3] = {0};
  uint32_t ndata = 3;
  uint32_t i;
  uint32_t max_addr = (1 << addr_w) - 1;
  addr[1] = max_addr;

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

int lru_test(uint32_t nways_w, uint32_t set_index_w, uint32_t word_offset_w) {
  uint32_t i = 0;
  uint32_t nways = (1 << nways_w);
  // Address step such that it targets the same cache set with a different tag.
  // uint32_t addr_step = 1 << (set_index_w + word_offset_w + byte_offset_w);
  uint32_t addr_step = ((1 << (set_index_w + word_offset_w)) * (DATA_W / 8));
  uint32_t addr = 0;
  uint32_t wdata = 0xDEADBEEF;

  // Write data
  for (i = 0, addr = 0; i < (2 * nways); i++, addr += addr_step) {
    printf("\tLRU: mem[%x] = %x\n", addr, wdata);
    iob_write(addr, DATA_W, wdata);
  }

  // Read back data
  for (i = 0, addr = 0; i < (2 * nways); i++, addr += addr_step) {
    printf("\tLRU: mem[%x] = %x\n", addr, iob_read(addr, DATA_W));
  }
  return 0;
}

void print_counters() {
  use_ctrl();
  printf("\tCache Counters:\n");
  printf("\tRW Hit:%d\n", iob_cache_csrs_get_RW_HIT());
  printf("\tRW Miss:%d\n", iob_cache_csrs_get_RW_MISS());
  printf("\tRead Hit:%d\n", iob_cache_csrs_get_READ_HIT());
  printf("\tRead Miss:%d\n", iob_cache_csrs_get_READ_MISS());
  printf("\tWrite Hit:%d\n", iob_cache_csrs_get_WRITE_HIT());
  printf("\tWrite Miss:%d\n", iob_cache_csrs_get_WRITE_MISS());
}

void wtb_status() {
  use_ctrl();
  printf("\tWrite Buffer Status:\n");
  printf("\t\tEmpty: %d\n", iob_cache_csrs_get_WTB_EMPTY());
  printf("\t\tFull: %d\n", iob_cache_csrs_get_WTB_FULL());
}

void reset_counters() {
  use_ctrl();
  iob_cache_csrs_set_RST_CNTRS(1);
}

int ctrl_test() {

  printf("CTRL Test\n");
  use_ctrl();
  printf("\tVersion: %x\n", iob_cache_csrs_get_version());

  wtb_status();
  print_counters();
  printf("\tResetting counters...");

  reset_counters();
  printf("done!\n");
  print_counters();

  iob_cache_csrs_set_INVALIDATE(1);
  iob_cache_csrs_set_INVALIDATE(0);

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

  failed += lru_test(IOB_CACHE_CSRS_NWAYS_W, IOB_CACHE_CSRS_SET_INDEX_W,
                     IOB_CACHE_CSRS_WORD_OFFSET_W);

  failed += ctrl_test();

  printf("CACHE test complete.\n");
  return failed;
}
