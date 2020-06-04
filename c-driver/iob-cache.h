#include <stdarg.h>
#include <stdlib.h>

#define CACHEFUNC(cache_base, func) (*((volatile int*) (cache_base + (func * sizeof(int)))))

static int cache_base;

//Function's memory map
#define INVALIDATE      0
#define BUFFER_EMPTY    1
#define BUFFER_FULL     2
#define HIT             3
#define MISS            4
#define READ_HIT        5
#define READ_MISS       6
#define WRITE_HIT       7
#define WRITE_MISS      8
#define COUNTER_RESET   9
#define INSTR_HIT       10 //for CTRL_CNT_ID only
#define INSTR_MISS      11 //for CTRL_CNT_ID only

// Cache Controllers's functions
//Static functions - system with singular cache
void cache_init(int cache_addr); // initialized the cache_base static integer
#define cache_invalidate    CACHEFUNC(cache_base,INVALIDATE)
#define cache_buffer_empty  CACHEFUNC(cache_base,BUFFER_EMPTY)
#define cache_buffer_full   CACHEFUNC(cache_base,BUFFER_FULL)
#define cache_hit           CACHEFUNC(cache_base,HIT)
#define cache_miss          CACHEFUNC(cache_base,MISS)
#define cache_read_hit      CACHEFUNC(cache_base,READ_HIT)
#define cache_read_miss     CACHEFUNC(cache_base,READ_MISS)
#define cache_write_hit     CACHEFUNC(cache_base,WRITE_HIT)
#define cache_write_miss    CACHEFUNC(cache_base,WRITE_MISS)
#define cache_counter_reset CACHEFUNC(cache_base,COUNTER_RESET)
#define cache_instr_hit     CACHEFUNC(cache_base,INSTR_HIT)
#define cache_instr_miss    CACHEFUNC(cache_base,INSTR_MISS)
//Addressable functions - system with multiple caches
#define cache_addr_invalidate(base)    CACHE_FUNC(base,INVALIDATE)
#define cache_addr_buffer_empty(base)  CACHE_FUNC(base,BUFFER_EMPTY)
#define cache_addr_buffer_full(base)   CACHE_FUNC(base,BUFFER_FULL)
#define cache_addr_hit(base)           CACHE_FUNC(base,HIT)
#define cache_addr_miss(base)          CACHE_FUNC(base,MISS)
#define cache_addr_read_hit(base)      CACHE_FUNC(base,READ_HIT)
#define cache_addr_read_miss(base)     CACHE_FUNC(base,READ_MISS)
#define cache_addr_write_hit(base)     CACHE_FUNC(base,WRITE_HIT)
#define cache_addr_write_miss(base)    CACHE_FUNC(base,WRITE_MISS)
#define cache_addr_counter_reset(base) CACHE_FUNC(base,COUNTER_RESET)
#define cache_addr_instr_hit(base)     CACHE_FUNC(base,INSTR_HIT)
#define cache_addr_instr_miss(base)    CACHE_FUNC(base,INSTR_MISS)
