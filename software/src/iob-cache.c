#include "iob-cache.h"

// base address of the cache controller

static int cache_base;

void cache_init(int ext_mem, int cache_addr) {
  cache_base = ext_mem + (1 << (cache_addr));
  IOB_CACHE_INIT_BASEADDR(cache_base);
}
