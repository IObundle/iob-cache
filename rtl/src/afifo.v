`timescale 1ns/1ps

module gray_counter #(parameter   COUNTER_WIDTH = 4)
   (
    input wire 		       rst, //Count reset.
    input wire 		       clk,
    input wire 		       en, //Count enable.
    output [COUNTER_WIDTH-1:0] data_out
    );

   reg [COUNTER_WIDTH-1:0]     bin_counter;
   reg [COUNTER_WIDTH-1:0]     gray_counter;

   assign data_out = gray_counter;
   
   always @ (posedge clk, posedge rst)
     if (rst) begin
        bin_counter   <= 1; 
        gray_counter <= 0; 
     end else if (en) begin
        bin_counter   <= bin_counter + 1'b1;
        gray_counter <= {bin_counter[COUNTER_WIDTH-1], bin_counter[COUNTER_WIDTH-2:0] ^ bin_counter[COUNTER_WIDTH-1:1]};
     end
   
endmodule

module iob_async_fifo
  #(parameter 
    DATA_WIDTH = 8, 
    ADDRESS_WIDTH = 4, 
    FIFO_DEPTH = (1 << ADDRESS_WIDTH)
    )
   (
    input 			rst,

    //read port
    output reg [DATA_WIDTH-1:0] data_out, 
    output 			empty,
    output [ADDRESS_WIDTH-1:0] 	level_r,
    input 			read_en,
    input 			rclk, 

    //write port	 
    input [DATA_WIDTH-1:0] 	data_in, 
    output 			full,
    output [ADDRESS_WIDTH-1:0] 	level_w,
    input 			write_en,
    input 			wclk
    );

   //FIFO memory
   reg [DATA_WIDTH-1:0] 	mem [FIFO_DEPTH-1:0];

   //WRITE DOMAIN 
   wire [ADDRESS_WIDTH-1:0] 	wptr;
   reg [ADDRESS_WIDTH-1:0] 	rptr_sync[1:0];
   wire                         write_en_int;
   
   //READ DOMAIN    
   wire [ADDRESS_WIDTH-1:0] 	rptr;
   reg [ADDRESS_WIDTH-1:0] 	wptr_sync[1:0];
   wire                         read_en_int;

   //convert gray to binary code
   function [ADDRESS_WIDTH-1:0] gray2bin;
      input reg [ADDRESS_WIDTH-1:0] gr;
      input integer                 N;
      begin: g2b
	 reg [ADDRESS_WIDTH-1:0] bi;
	 integer                 i;
	 
	 bi[N-1] = gr[N-1];
	 for (i=N-2;i>=0;i=i-1)
           bi[i] = gr[i] ^ bi[i+1];
	 
	 gray2bin = bi;
      end
   endfunction
   
   //WRITE DOMAIN LOGIC

   //sync read pointer
   always @ (posedge wclk) begin 
      rptr_sync[0] <= rptr;
      rptr_sync[1] <= rptr_sync[0];
   end
   
   //effective write enable
   assign write_en_int = write_en & ~full;
   
   //write
   always @ (posedge wclk)
     if (write_en_int)
       mem[wptr] <= data_in;

   gray_counter #(ADDRESS_WIDTH) wptr_counter (
                                               .clk(wclk),
                                               .rst(rst), 
                                               .en(write_en_int),
                                               .data_out(wptr)
                                               );
   //compute binary pointer difference
   assign level_w = gray2bin(wptr, ADDRESS_WIDTH) - gray2bin(rptr_sync[1], ADDRESS_WIDTH);
   
   assign full = (level_w == (FIFO_DEPTH-1));

   
   //READ DOMAIN LOGIC

   //sync write pointer
   always @ (posedge rclk) begin 
      wptr_sync[0] <= wptr;
      wptr_sync[1] <= wptr_sync[0];
   end

   //effective read enable
   assign read_en_int  = read_en & ~empty;
   
   //read
   always @ (posedge rclk)
     if (read_en_int)
       data_out <= mem[rptr];

   gray_counter #(ADDRESS_WIDTH) rptr_counter (
                                               .clk(rclk),
                                               .rst(rst), 
                                               .en(read_en_int),
                                               .data_out(rptr)
                                               );
   
   //compute binary pointer difference
   assign level_r = gray2bin(wptr_sync[1], ADDRESS_WIDTH) - gray2bin(rptr, ADDRESS_WIDTH);
   

   assign empty = (level_r == 0);
   

endmodule

