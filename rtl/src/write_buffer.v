`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/28/2019 04:47:55 PM
// Design Name: 
// Module Name: write_buffer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module dwt_buffer_v2(
   clock,
   reset,
   we,
   datain,
   full,
   rd,
   dataout,
   empty
);

   parameter WORDSIZE = 66;
   parameter MEMSIZE = 1;   // = 2**MEMSIZE words

   input     clock;
   input     reset;
   input     we;
   input     rd;
   input     [WORDSIZE-1:0] datain;
   output    full;
   output    [WORDSIZE-1:0] dataout;
   output    empty;

   localparam C_FULL_LENGHT = 2**MEMSIZE;

   wire      clock;
   wire      reset;
   wire      we;
   wire      [WORDSIZE-1:0] datain;
   wire      full;
   wire      rd;
   reg       [WORDSIZE-1:0] dataout;
   wire      empty;

   reg       [WORDSIZE-1:0] ram_mem [(2**MEMSIZE)-1:0];
//   reg       [MEMSIZE-1:0] read_dpra;
   reg       [MEMSIZE-1:0] read_address;
   reg       [MEMSIZE-1:0] write_address;
   reg       [MEMSIZE-1:0] fifo_length;
   reg       [MEMSIZE-1:0] fifo_length_nxt;
   wire      full_int;
   wire      empty_int;
   wire      rd_int;
   wire      we_int;

   assign full = full_int;
   assign empty = empty_int;
   assign empty_int = fifo_length == 0 ? 1'b1 : 1'b0;
   
   // FIFO cannot use all positions because the read operation relies on the fact that
   // the data remains stable in the "dataout" port until acknowledge by the DMA controller
   assign full_int = fifo_length == ($unsigned(C_FULL_LENGHT) - 1'b1) ? 1'b1 : 1'b0;
   
   assign rd_int = rd & ~empty_int;
   assign we_int = we & ~full_int;

   always @(posedge clock or posedge reset)
   begin
      if (reset == 1'b1)
      begin
         write_address             <= {(MEMSIZE){1'b0}};
         read_address              <= {(MEMSIZE){1'b0}};
         fifo_length               <= {(MEMSIZE){1'b0}};
      end
      else
      begin
         if (rd_int == 1'b1)
            read_address           <= read_address + 1'b1;
         if (we_int == 1'b1)
            write_address          <= write_address + 1'b1;
         fifo_length               <= fifo_length_nxt;
      end
   end

   always @(posedge clock) // or posedge reset)
   begin
//      if (reset == 1'b1)
//         read_address              <= {(MEMSIZE){1'b0}};
//      else
//      begin
         if (rd_int == 1'b1)
         begin
            dataout                <= ram_mem[read_address];
         end
         if (we_int == 1'b1)
            ram_mem[write_address] <= datain;
//      end
   end

//          read_dpra              <= read_address;

   always @(fifo_length or we_int or rd_int)
   begin
      fifo_length_nxt              = fifo_length;
      // write and no read => increment length
      if ((we_int == 1'b1) && (rd_int == 1'b0))
         fifo_length_nxt           = fifo_length + 1'b1;
      else
      begin
         // read and no write => decrement length
         if ((we_int == 1'b0) && (rd_int == 1'b1))
            fifo_length_nxt        = fifo_length - 1'b1;
      end
   end

endmodule
