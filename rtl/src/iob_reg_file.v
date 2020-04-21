module iob_reg_file #(
                      parameter NUM_COL = 4,
                      parameter COL_WIDTH = 8,
                      parameter ADDR_WIDTH = 10,  
                      //Addr Width in bits : 2*ADDR_WIDTH = RAM Depth
                      parameter DATA_WIDTH = NUM_COL*COL_WIDTH  //Data Width in bits		        
		      )
   (      
	  input                    clk,
          input                    rst,
	  input [DATA_WIDTH-1:0]   wdata,
	  input [ADDR_WIDTH-1:0]   addr,
	  input [NUM_COL-1:0]      en,
	  output [DATA_WIDTH-1 :0] rdata
	  );
   
   genvar                          i;
   integer                         j;
   
   generate
      for (i = 0; i < NUM_COL; i=i+1)
        begin

           reg [COL_WIDTH-1:0]             regfile [2**ADDR_WIDTH-1:0]; 
           
           always @ (posedge clk)
             begin
                if (rst)
                  for (j=0; j < 2**ADDR_WIDTH; j=j+1) //resets the entire memory
                    regfile[j] <= {COL_WIDTH{1'b0}};
                else
                  if (en[i])
                    regfile [addr] <= wdata [COL_WIDTH*(i+1) -1: COL_WIDTH*i];
             end 
           
           assign rdata [COL_WIDTH*(i+1) -1: COL_WIDTH*i] = regfile [addr];
           
        end                                             
   endgenerate
   
endmodule // iob_reg_file
