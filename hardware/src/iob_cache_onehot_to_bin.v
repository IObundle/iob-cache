`timescale 1ns / 1ps

/*---------------------------*/
/* One-Hot to Binary Encoder */
/*---------------------------*/

// One-hot to binary encoder (if input is (0)0 or (0)1, the output is 0)
module iob_cache_onehot_to_bin #(
   parameter BIN_W = 2
) (
   input      [2**BIN_W-1:1] onehot_i,
   output reg [   BIN_W-1:0] bin_o
);

   reg     [BIN_W-1:0] bin_cnt;
   integer             i;

   always @(onehot_i) begin : onehot_to_binary_encoder
      bin_cnt = 0;
      for (i = 1; i < 2 ** BIN_W; i = i + 1) if (onehot_i[i]) bin_cnt = bin_cnt | i[BIN_W-1:0];
      bin_o = bin_cnt;
   end

endmodule
