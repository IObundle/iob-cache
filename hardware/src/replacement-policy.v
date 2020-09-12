`timescale 1ns / 1ps
`include "iob-cache.vh"

/*--------------------*/
/* Replacement Policy */
/*--------------------*/
// Module that contains all iob-cache's replacement policies

module replacement_process 
  #(
    parameter N_WAYS     = 16,
    parameter LINE_OFF_W = 6,
    parameter NWAY_W = $clog2(N_WAYS),
    parameter REP_POLICY = `LRU //LRU - Least Recently Used; LRU_stack (LRU that uses shifts as a stack) ; BIT_PLRU (1) - bit-based pseudoLRU; TREE_PLRU (2) - tree-based pseudoLRU
    )
   (
    input                  clk,
    input                  reset,
    input                  write_en,
    input [N_WAYS-1:0]     way_hit,
    input [LINE_OFF_W-1:0] line_addr,
    output [N_WAYS-1:0]    way_select,
    output [NWAY_W-1:0]    way_select_bin 
    );


   genvar                  i, j, k;

   generate
      if (REP_POLICY == `LRU)
        begin
           
           wire [N_WAYS*NWAY_W -1:0] mru_output, mru_input;
           wire [N_WAYS*NWAY_W -1:0] mru_init; //Initial MRU values of the LRU algorithm, also initialized them in case it's the first access or was invalidated
           wire [N_WAYS*NWAY_W -1:0] mru_cnt; //updates the MRU line, the way used will be the highest value, while the others are decremented
           wire [NWAY_W -1:0]        mru_hit_val [N_WAYS :0]; //Value of the MRU way
           wire [N_WAYS -1:0]        lru_sel; //LRU way, selected form the one with the lowest MRU value
           assign mru_hit_val [0] [NWAY_W -1:0] = {NWAY_W{1'b0}}; //
           
           for (i = 0; i < N_WAYS; i=i+1)
	     begin : lru_counter_algorithm
	        assign mru_init [i*NWAY_W +: NWAY_W] = (|mru_output)? mru_output [i*NWAY_W +: NWAY_W] : i; //verifies if the mru line has been initialized (if any bit in mru_output is HIGH), otherwise applies the priority values
                assign mru_hit_val [i+1][NWAY_W -1:0]  = mru_hit_val[i][NWAY_W-1:0] | ({NWAY_W{way_hit[i]}} & mru_init[(i+1)*NWAY_W -1: i*NWAY_W]); //stores the value of the MRU way
                assign mru_cnt [i*NWAY_W +: NWAY_W] = (way_hit[i])? {NWAY_W{1'b1}} : (mru_init [i*NWAY_W +: NWAY_W] > mru_hit_val [N_WAYS]) ? mru_init [i*NWAY_W +: NWAY_W] - 1 : mru_init [i*NWAY_W +: NWAY_W];// the MRU way gets updated to the the highest value; the remaining, if their value was bigger than the MRU previous value, they get decremented

                assign lru_sel [i] = ~(|mru_init[i*NWAY_W +: NWAY_W]); //selects the way that has the lowest priority (mru_init = 0)              
             end
           
           assign way_select = lru_sel;
           
           assign mru_input = (|way_hit)? mru_cnt : mru_output; //If an hit occured, then it updates, to avoid updating during a write-miss
           
           //Selects the least recent used way (encoder for one-hot to binary format)
           onehot_to_bin #(
                           .BIN_W (NWAY_W)	       
                           ) 
           lru_select
             (    
                  .onehot(lru_sel[N_WAYS-1:1]),
                  .bin(way_select_bin)
                  );

           
           //Most Recently Used (MRU) memory	   
           iob_reg_file
             #(
               .ADDR_WIDTH (LINE_OFF_W),		
               .COL_WIDTH (N_WAYS*NWAY_W),
               .NUM_COL (1)
               ) 
           mru_memory //simply uses the same format as valid memory
             (
              .clk  (clk          ),
              .rst  (reset        ),
              .wdata(mru_input    ),
              .rdata(mru_output   ),			             
              .addr (line_addr    ),
              .en   (write_en     )
              );
           
        end // if (REP_POLICU == `LRU)
      else if (REP_POLICY == `BIT_PLRU)
        begin

           wire [N_WAYS -1:0]      mru_output;
           wire [N_WAYS -1:0]      mru_input = (&(mru_output | way_hit))? {N_WAYS{1'b0}} : mru_output | way_hit; //When the cache access results in a hit (or access (wish would be 1 in way_hit even during a read-miss), it will add to the MRU, if after the the OR with Way_hit, the entire input is 1s, it resets
           wire [N_WAYS -1:0]      bitplru; //least recent used 
           
           assign bitplru[0] = ~mru_output[0];

           for (i = 1; i < N_WAYS; i=i+1)
	     begin : bitplru_priority
                assign bitplru [i] = ~mru_output[i] & (&mru_output[i-1:0]); //verifies priority (lower index)
             end  


           assign way_select = bitplru;
           
           //Selects the least recent used way (encoder for one-hot to binary format)
           onehot_to_bin #(
                           .BIN_W (NWAY_W)	       
                           ) 
           lru_select
             (      
                    .onehot(bitplru[N_WAYS-1:1]),
                    .bin(way_select_bin)
                    );

           
           //Most Recently Used (MRU) memory	   
           iob_reg_file
             #(
               .ADDR_WIDTH (LINE_OFF_W),
               .COL_WIDTH (N_WAYS),
               .NUM_COL (1)
               ) 
           mru_memory //simply uses the same format as valid memory
             (
              .clk  (clk          ),
              .rst  (reset        ),
              .wdata(mru_input    ),
              .rdata(mru_output   ),			            
              .addr (line_addr    ),
              .en   (write_en     )
              );

           
        end // if (REP_POLICY == BIT_PLRU)
      else // (REP_POLICY == TREE_PLRU)
        begin
           
           wire [N_WAYS -1: 1] t_plru, t_plru_output;
           wire [N_WAYS -1: 0] nway_tree [NWAY_W: 0]; // the order of the way line_addr will be [lower; ...; higher way line_addr], for readable reasons
           wire [N_WAYS -1: 0] tplru_sel;
           
           // Tree-structure: t_plru[i] = tree's bit i (0 - top, towards bottom of the tree)
           for (i = 1; i <= NWAY_W; i = i + 1)
	     begin : tree_bit
	        for (j = 0; j < (1<<(i-1)) ; j = j + 1)
	          begin : tree_structure
		     assign t_plru [(1<<(i-1))+j] = (t_plru_output[(1<<(i-1))+j] && (~(|way_hit[(N_WAYS-(2*j+1)*(N_WAYS>>i)) -1: N_WAYS-(2*j+2)*(N_WAYS>>i)]))) || (|way_hit[N_WAYS-(2*j*(N_WAYS>>i)) -1: N_WAYS-(2*j+1)*(N_WAYS>>i)]); // (t-bit * (~|way_hit[lower_section]) + |way_hit[top_section])
	          end
	     end
           
           // Tree's Encoder (to translate it into selectable way) -- nway_tree will represent the line_addres of the way to be selected, but it's order is inverted to be more readable (check treeplru_sel)
           assign nway_tree [0] = {N_WAYS{1'b1}}; // the first position of the tree's matrix will be all 1s, for the AND logic of the following algorithm work properlly
           for (i = 1; i <= NWAY_W; i = i + 1)
	     begin : encoder_bit
	        for (j = 0; j < (1 << (i-1)); j = j + 1)
	          begin :  encoder_microposition
		     for (k = 0; k < (N_WAYS >> i); k = k + 1)
		       begin : encoder_macroposition
		          assign nway_tree [i][j*(N_WAYS >> (i-1)) + k] = nway_tree [i-1][j*(N_WAYS >> (i-1)) + k] && ~(t_plru_output [(1 << (i-1)) + j]); // the first half will be the Tree's bit inverted (0 equal Left (upper position)
		          assign nway_tree [i][j*(N_WAYS >> (i-1)) + k + (N_WAYS >> i)] = nway_tree [i-1][j*(N_WAYS >> (i-1)) + k] && t_plru_output [(1 << (i-1)) + j]; //second half of the same Tree's bit (1 equals Right (lower position))
		       end	
	          end
	     end 
           // placing the way select wire in the correct order for the onehot-binary encoder
           for (i = 0; i < N_WAYS; i = i + 1)
	     begin : way_selector
	        assign tplru_sel[i] = nway_tree [NWAY_W][N_WAYS - i -1];//the last row of nway_tree has the result of the Tree's encoder
	     end


           assign way_select = tplru_sel;
           
           //Selects the least recent used way (encoder for one-hot to binary format)
           onehot_to_bin #(
                           .BIN_W (NWAY_W)	       
                           ) 
           lru_select
             (
              .onehot(tplru_sel[N_WAYS-1:1]),
              .bin(way_select_bin)
              );

           
           //Most Recently Used (MRU) memory	   
           iob_reg_file
             #(
               .ADDR_WIDTH (LINE_OFF_W),
               .COL_WIDTH (N_WAYS-1),
               .NUM_COL (1)
               ) 
           mru_memory //simply uses the same format as valid memory
             (
              .clk  (clk          ),
              .rst  (reset        ),
              .wdata(t_plru       ),
              .rdata(t_plru_output),     
              .addr (line_addr    ),
              .en   (write_en     )
              );
           
        end // else: !if(REP_POLICY == BIT_PLRU)
   endgenerate

endmodule
