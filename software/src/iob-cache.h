#include <stdarg.h>
#include <stdlib.h>

#define CACHEFUNC(cache_base, func)                                            \
  (*((volatile int *)(cache_base + (func * sizeof(int)))))

// Function's memory map
#define BUFFER_EMPTY 0
#define BUFFER_FULL 1
#define HIT 4
#define MISS 8
#define READ_HIT 12
#define READ_MISS 16
#define WRITE_HIT 20
#define WRITE_MISS 24
#define COUNTER_RESET 28
#define INVALIDATE 29
#define CACHE_VERSION 30

// Cache Controllers's functions
void cache_init(int ext_mem,
                int cache_addr); // initialized the cache_base static integer
int cache_invalidate();
int cache_wtb_empty();
int cache_wtb_full();
int cache_hit();
int cache_miss();
int cache_read_hit();
int cache_read_miss();
int cache_write_hit();
int cache_write_miss();
int cache_counter_reset();
int cache_version();
