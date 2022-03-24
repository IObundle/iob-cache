    //Master i/f (do not remove indentation)
    //START_IO_TABLE iob_m
    `IOB_INPUT(valid,         1),                        //Native CPU interface valid signal
`ifdef WORD_ADDR
    `IOB_INPUT(addr,CTRL_CACHE + FE_ADDR_W - FE_BYTE_W), //Native CPU interface address signal
`else
    `IOB_INPUT(addr,CTRL_CACHE + FE_ADDR_W),             //Native CPU interface address signal
`endif
    `IOB_INPUT(wdata, FE_DATA_W),                        //Native CPU interface write data signal
    `IOB_INPUT(wstrb, FE_NBYTES),                        //Native CPU interface write strobe signal
    `IOB_OUTPUT(rdata,FE_DATA_W),                        //Native CPU interface read data signal
    `IOB_OUTPUT(ready,        1),                        //Native CPU interface ready signal
      
