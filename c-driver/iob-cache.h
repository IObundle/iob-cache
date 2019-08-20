#include <stdint.h>

#define reg_cache_instr_hit        (*(volatile uint32_t*)  0xC0000000)
#define reg_cache_instr_read_miss  (*(volatile uint32_t*)  0xC0000004)
#define reg_cache_instr_write_miss (*(volatile uint32_t*)  0xC0000008)
#define reg_cache_data_hit         (*(volatile uint32_t*)  0xC000000C)
#define reg_cache_data_read_miss   (*(volatile uint32_t*)  0xC0000010)
#define reg_cache_data_write_miss  (*(volatile uint32_t*)  0xC0000014)
#define reg_cache_hit              (*(volatile uint32_t*)  0xC0000018)
#define reg_cache_instr_miss       (*(volatile uint32_t*)  0xC000001C)
#define reg_cache_data_miss        (*(volatile uint32_t*)  0xC0000020)
#define cache_invalidate           (*(volatile uint32_t*)  0xC000003C)
