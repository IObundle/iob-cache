#include "iob-cache.h"

//base address of the cache controller

static int cache_base;

void cache_init(int cache_addr)
{
  cache_base = 1 << (cache_addr);
}

int cache_hit()
{
  return (CACHEFUNC(cache_base,HIT));
}

int cache_miss()
{
  return (CACHEFUNC(cache_base,MISS));
}

int cache_instr_hit()
{
  return (CACHEFUNC(cache_base,INSTR_HIT));
}

int cache_instr_miss()
{
  return (CACHEFUNC(cache_base,INSTR_MISS));
}

int cache_data_hit()
{
  return (CACHEFUNC(cache_base,DATA_HIT));
}

int cache_data_miss()
{
  return (CACHEFUNC(cache_base,DATA_MISS));
}


int cache_data_read_hit()
{
  return (CACHEFUNC(cache_base,DATA_READ_HIT));
}

int cache_data_read_miss()
{
  return (CACHEFUNC(cache_base,DATA_READ_MISS));
}

int cache_data_write_hit()
{
  return (CACHEFUNC(cache_base,DATA_WRITE_HIT));
}

int cache_data_write_miss()
{
  return (CACHEFUNC(cache_base,DATA_WRITE_MISS));
}

int cache_counter_reset()
{
  return (CACHEFUNC(cache_base,COUNTER_RESET));
}

int cache_invalidate()
{
  return (CACHEFUNC(cache_base,INVALIDATE));
}

int cache_clock_start()
{
  return (CACHEFUNC(cache_base,CLOCK_START));
}

int cache_clock_stop()
{
  return (CACHEFUNC(cache_base,CLOCK_STOP));
}

int cache_clock_upper()
{
  return (CACHEFUNC(cache_base,CLOCK_UPPER));
}

int cache_clock_lower()
{
  return (CACHEFUNC(cache_base,CLOCK_LOWER));
}

int cache_buffer_empty()
{
  return (CACHEFUNC(cache_base,BUFFER_EMPTY));
}

int cache_buffer_full()
{
  return (CACHEFUNC(cache_base,BUFFER_FULL));
}
