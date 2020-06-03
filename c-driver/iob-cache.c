#include "iob-cache.h"

//base address of the cache controller

static int cache_base;

void cache_init(int cache_addr)
{
  cache_base = 1 << (cache_addr);
}
