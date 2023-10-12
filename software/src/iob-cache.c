#include "iob-cache.h"

// base address of the cache controller

static int cache_base;

void cache_init(int ext_mem, int cache_addr) {
  cache_base = ext_mem + (1 << (cache_addr));
}

int cache_invalidate() { return (CACHEFUNC(cache_base, IOB_CACHE_INVALIDATE)); }

int cache_wtb_empty() { return (CACHEFUNC(cache_base, IOB_CACHE_WTB_EMPTY)); }

int cache_wtb_full() { return (CACHEFUNC(cache_base, IOB_CACHE_WTB_FULL)); }

int cache_hit() { return (CACHEFUNC(cache_base, IOB_CACHE_RW_HIT)); }

int cache_miss() { return (CACHEFUNC(cache_base, IOB_CACHE_RW_MISS)); }

int cache_read_hit() { return (CACHEFUNC(cache_base, IOB_CACHE_READ_HIT)); }

int cache_read_miss() { return (CACHEFUNC(cache_base, IOB_CACHE_READ_MISS)); }

int cache_write_hit() { return (CACHEFUNC(cache_base, IOB_CACHE_WRITE_HIT)); }

int cache_write_miss() { return (CACHEFUNC(cache_base, IOB_CACHE_WRITE_MISS)); }

int cache_counter_reset() {
  return (CACHEFUNC(cache_base, IOB_CACHE_RST_CNTRS));
}

int cache_version() { return (CACHEFUNC(cache_base, IOB_CACHE_VERSION)); }
