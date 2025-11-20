// SPDX-FileCopyrightText: 2024 IObundle
//
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps

/*---------------------------------*/
/* Byte-width generable iob-sp-ram */
/*---------------------------------*/

// For cycle that generates byte-width (single enable) single-port SRAM
// older synthesis tool may require this approach

module iob_cache_gen_sp_ram #(
   parameter DATA_W = 32,
   parameter ADDR_W = 10
) (
   input                 clk_i,
   input                 en_i,
   input  [DATA_W/8-1:0] we_i,
   input  [  ADDR_W-1:0] addr_i,
   output [  DATA_W-1:0] data_o,
   input  [  DATA_W-1:0] data_i
);

   genvar i;
   generate
      for (i = 0; i < (DATA_W / 8); i = i + 1) begin : g_ram
         iob_ram_sp #(
            .DATA_W(8),
            .ADDR_W(ADDR_W)
         ) iob_cache_mem (
            .clk_i (clk_i),
            .en_i  (en_i),
            .we_i  (we_i[i]),
            .addr_i(addr_i),
            .d_o   (data_o[8*i+:8]),
            .d_i   (data_i[8*i+:8])
         );
      end
   endgenerate

endmodule
