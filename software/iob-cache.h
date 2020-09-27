#include <stdarg.h>
#include <stdlib.h>

static int cache_base;

#define CACHEFUNC(cache_base, func) (*((volatile int*) (cache_base + (func * sizeof(int)))))

//Function's memory map
#define INVALIDATE      1
#define BUFFER_EMPTY    2
#define BUFFER_FULL     3
#define HIT             4
#define MISS            5
#define READ_HIT        6
#define READ_MISS       7
#define WRITE_HIT       8
#define WRITE_MISS      9
#define COUNTER_RESET   10
#define INSTR_HIT       11 //for CTRL_CNT_ID only
#define INSTR_MISS      12 //for CTRL_CNT_ID only

// Cache Controllers's functions
void cache_init(int ext_mem, int cache_addr); // initialized the cache_base static integer
int cache_invalidate(); 
int cache_buffer_empty();    
int cache_buffer_full();
int cache_hit();        
int cache_miss();                       
int cache_read_hit();    
int cache_read_miss(); 
int cache_write_hit();  
int cache_write_miss();  
int cache_counter_reset();  
int cache_instr_hit();       
int cache_instr_miss();
