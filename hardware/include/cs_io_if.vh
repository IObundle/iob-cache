    //control-status i/o (do not remove indentation)
    //START_IO_TABLE cs_io
    `IOB_INPUT(force_inv_in,  1),     //force 1'b0 if unused
    `IOB_OUTPUT(force_inv_out,1),     //cache invalidate signal
    `IOB_INPUT(wtb_empty_in,  1),     //force 1'b1 if unused
    `IOB_OUTPUT(wtb_empty_out,1),     //write-through buffer empty signal
