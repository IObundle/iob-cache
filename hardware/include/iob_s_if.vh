    //Slave i/f - Native (do not remove indentation)
    //START_IO_TABLE iob_s
    `IOB_OUTPUT(mem_valid,       1),    //Native CPU interface valid signal
    `IOB_OUTPUT(mem_addr,BE_ADDR_W),    //Native CPU interface address signal
    `IOB_OUTPUT(mem_wdata,BE_DATA_W),   //Native CPU interface write data signal
    `IOB_OUTPUT(mem_wstrb,BE_NBYTES),   //Native CPU interface write strobe signal
    `IOB_INPUT(mem_rdata,BE_DATA_W),    //Native CPU interface read data signal
    `IOB_INPUT(mem_ready,        1)     //Native CPU interface ready signal
