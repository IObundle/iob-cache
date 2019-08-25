`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/17/2019 02:14:54 PM
// Design Name: 
// Module Name: tag_memory
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


module tag_memory #(
		    parameter ADDR_W = 20,
		    parameter DATA_W = 20	          
                    )
   (      
	  input 	      clk, 
	  input [DATA_W-1:0]  tag_write_data,
	  input [ADDR_W-1:0]  tag_addr,
	  input 	      tag_en,
	  output [DATA_W-1:0] tag_read_data
	  );





   // TAG MEMORY SYSTEM

   xalt_1p_mem_no_initialization  #(
					       .DATA_W(DATA_W),
					       .ADDR_W(ADDR_W))
   tag_mem
     (
      .data_a   (tag_write_data),
      .addr_a   (tag_addr),
      .we_a     (tag_en),
      .q_a      (tag_read_data),
      .clk      (clk)
      );

endmodule
