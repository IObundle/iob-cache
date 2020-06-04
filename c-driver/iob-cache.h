#include <stdarg.h>
#include <stdlib.h>

static int cache_base;

#define CACHEFUNC(cache_base, func) (*((volatile int*) (cache_base + (func * sizeof(int)))))

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
void cache_init(int cache_addr); // initialized the cache_base static integer
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
