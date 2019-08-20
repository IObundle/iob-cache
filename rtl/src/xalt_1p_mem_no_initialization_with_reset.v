`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/17/2019 02:58:04 PM
// Design Name: 
// Module Name: xalt_1p_mem_no_initialization_with_reset
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


module xalt_1p_mem_no_initialization_with_reset #(
		      parameter DATA_W=8,
              parameter ADDR_W=20
)
(
input [(DATA_W-1):0]      data_a,
input [(ADDR_W-1):0]      addr_a,
input                     we_a, clk, rst, 
output reg [(DATA_W-1):0] q_a
);

// Declare the RAM
reg [DATA_W-1:0]                    ram[2**ADDR_W-1:0];

integer j;

// Operate the RAM
always @ (posedge clk)
begin // Port A
    if (rst) begin //negative reset clause
        for (j=0; j < 2**ADDR_W; j=j+1) begin
            ram[j] <= {(DATA_W){1'b0}}; //reset array
        end
    end else if (we_a)
    begin
        ram[addr_a] <= data_a;
        //q_a <= data_a;
    end
    else
        q_a <= ram[addr_a];
end

endmodule
