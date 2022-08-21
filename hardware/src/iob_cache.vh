//DERIVED MACROS
`define NBYTES (DATA_W/8)
`define NBYTES_W ($clog2(`NBYTES))
`define BE_NBYTES (BE_DATA_W/8)
`define BE_NBYTES_W ($clog2(`BE_NBYTES))
`define LINE2BE_W (WORD_OFFSET_W-$clog2(BE_DATA_W/DATA_W))
