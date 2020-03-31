#include <stdarg.h>
#include <stdlib.h>

#define CACHEFUNC(cache_base, func) (*((volatile int*) (cache_base + (func * sizeof(int)))))

//Function's memory map
#define HIT             0
#define MISS            1
#define INSTR_HIT       2
#define INSTR_MISS      3
#define DATA_HIT        4
#define DATA_MISS       5
#define DATA_READ_HIT   6
#define DATA_READ_MISS  7
#define DATA_WRITE_HIT  8
#define DATA_WRITE_MISS 9
#define COUNTER_RESET   10
#define INVALIDATE      11
#define CLOCK_START     12
#define CLOCK_STOP      13
#define CLOCK_UPPER     14
#define CLOCK_LOWER     15
#define BUFFER_EMPTY    16
#define BUFFER_FULL     17

// Cache Controllers's functions
void cache_init(int cache_addr);
int cache_hit();        
int cache_miss();           
int cache_instr_hit();       
int cache_instr_miss();       
int cache_data_hit();        
int cache_data_miss();      
int cache_data_read_hit();    
int cache_data_read_miss(); 
int cache_data_write_hit();  
int cache_data_write_miss();  
int cache_counter_reset();  
int cache_invalidate();     
int cache_clock_start();    
int cache_clock_stop();     
int cache_clock_upper();   
int cache_clock_lower();   
int cache_buffer_empty();    
int cache_buffer_full(); 
