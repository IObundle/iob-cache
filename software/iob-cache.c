#include "iob-cache.h"

//base address of the cache controller

static int cache_base;

void cache_init(int ext_mem, int cache_addr)
{
  cache_base = ext_mem + (1 << (cache_addr));
}

int cache_invalidate()   {return (CACHEFUNC(cache_base,INVALIDATE));}

int cache_buffer_empty() {return (CACHEFUNC(cache_base,BUFFER_EMPTY));}

int cache_buffer_full()  {return (CACHEFUNC(cache_base,BUFFER_FULL));}

int cache_hit()          {return (CACHEFUNC(cache_base,HIT));}

int cache_miss()         {return (CACHEFUNC(cache_base,MISS));}

int cache_read_hit()     {return (CACHEFUNC(cache_base,READ_HIT));}

int cache_read_miss()    {return (CACHEFUNC(cache_base,READ_MISS));}

int cache_write_hit()    {return (CACHEFUNC(cache_base,WRITE_HIT));}

int cache_write_miss()   {return (CACHEFUNC(cache_base,WRITE_MISS));}

int cache_counter_reset(){return (CACHEFUNC(cache_base,COUNTER_RESET));}

