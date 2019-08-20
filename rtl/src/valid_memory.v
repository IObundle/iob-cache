`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/17/2019 02:14:54 PM
// Design Name: 
// Module Name: valid_memory
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


module valid_memory #(
		      parameter ADDR_W = 20,
		      parameter DATA_W = 1              
                      )
   (      
	  input 	      clk,
	  input 	      reset, 
	  input [DATA_W-1:0]  v_write_data,
	  input [ADDR_W-1:0]  v_addr,
	  input 	      v_en,
	  output [DATA_W-1:0] v_read_data
	  );





   // TAG MEMORY SYSTEM

   xalt_1p_mem_no_initialization_with_reset  #(
					       .DATA_W(DATA_W),
					       .ADDR_W(ADDR_W))
   tag_mem
     (
      .data_a   (v_write_data),
      .addr_a   (v_addr),
      .we_a     (v_en),
      .q_a      (v_read_data),
      .rst      (reset),
      .clk      (clk)
      );
   
endmodule
