`timescale 1ns / 1ps


module generable_memory #(
		          parameter ADDR_W = 10,
                          parameter DATA_W = 32,         // Total size of the memory (N_MEM x MEM_W)
                          parameter MEM_W  = 8,    // Size of each individual memory
                          parameter N_MEM  = DATA_W/MEM_W// Number of individual memories 
		          )
   (      
	  input                clk,
	  input [DATA_W-1:0]   mem_write_data,
	  input [ADDR_W-1:0]   mem_addr,
	  input [N_MEM-1:0]    mem_en,
	  output [DATA_W-1 :0] mem_read_data
	  );
   
   genvar                      i;
   integer                     j;
   
   generate
      for (i = 0; i < N_MEM; i=i+1)
        begin

           reg [MEM_W-1:0]             mem [2**ADDR_W-1:0]; //each individual memory 
           
           always @ (posedge clk)
             begin
                  if (mem_en[i])
                    mem [mem_addr] <= mem_write_data [MEM_W*(i+1) -1: MEM_W*i];
             end 
           
           assign mem_read_data [MEM_W*(i+1) -1: MEM_W*i] = mem [mem_addr];
           
        end                                             
   endgenerate
   
endmodule



module generable_reg_file #(
		          parameter ADDR_W = 10,
                          parameter DATA_W = 32,         // Total size of the memory (N_MEM x MEM_W)
                          parameter MEM_W  = 8,    // Size of each individual memory
                          parameter N_MEM  = DATA_W/MEM_W// Number of individual memories 
		          )
   (      
	  input                clk,
          input                rst,
	  input [DATA_W-1:0]   mem_write_data,
	  input [ADDR_W-1:0]   mem_addr,
	  input [N_MEM-1:0]    mem_en,
	  output [DATA_W-1 :0] mem_read_data
	  );
   
   genvar                      i;
   integer                     j;
   
   generate
      for (i = 0; i < N_MEM; i=i+1)
        begin

           reg [MEM_W-1:0]             mem [2**ADDR_W-1:0]; //each individual memory 
           
           always @ (posedge clk)
             begin
                if (rst)
                  for (j=0; j < 2**ADDR_W; j=j+1) //resets the entire memory
                    mem[j] <= {MEM_W{1'b0}};
                else
                  if (mem_en[i])
                    mem [mem_addr] <= mem_write_data [MEM_W*(i+1) -1: MEM_W*i];
             end 
           
           assign mem_read_data [MEM_W*(i+1) -1: MEM_W*i] = mem [mem_addr];
           
        end                                             
   endgenerate
   
endmodule
