`timescale 1ns / 1ps
`include "iob-cache.vh"

/*--------------------*/
/* Replacement Policy */
/*--------------------*/
// Module that contains all iob-cache's replacement policies

module replacement_policy 
  #(
    parameter N_WAYS     = 4,
    parameter LINE_OFF_W = 7,
    parameter NWAY_W = $clog2(N_WAYS),
    parameter REP_POLICY = `LRU //LRU - Least Recently Used; PLRU_mru (1) - mru-based pseudoLRU; PLRU_tree (3) - tree-based pseudoLRU 
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
   
   onehot_to_bin #(
                   .BIN_W (NWAY_W)	       
                   ) 
   onehot_bin
     (    
          .onehot(way_select[N_WAYS-1:1]),
          .bin(way_select_bin)
          );
   
   genvar                  i, j, k;

   generate
      if (REP_POLICY == `LRU)
        begin
           
           wire [N_WAYS*NWAY_W -1:0] mru_out, mru_in;
           wire [N_WAYS*NWAY_W -1:0] mru; //Initial MRU values of the LRU algorithm, also initialized them in case it's the first access or was invalidated
           wire [N_WAYS*NWAY_W -1:0] mru_cnt; //updates the MRU line, the way used will be the highest value, while the others are decremented
           wire [NWAY_W -1:0]        mru_index [N_WAYS :0]; //Index value of the MRU way
           
           assign mru_index [0] [NWAY_W -1:0] = {NWAY_W{1'b0}}; //
           
           for (i = 0; i < N_WAYS; i=i+1)
	     begin : encoder_decoder
                //LRU - Endocer
	        assign mru [i*NWAY_W +: NWAY_W] = (|mru_out)? mru_out [i*NWAY_W +: NWAY_W] : i; //verifies if the mru line has been initialized (if any bit in mru_output is HIGH), otherwise applies the priority values
                assign mru_index [i+1][NWAY_W -1:0]  = mru_index[i][NWAY_W-1:0] | ({NWAY_W{way_hit[i]}} & mru[(i+1)*NWAY_W -1: i*NWAY_W]); //stores the  index-value of the MRU way
                assign mru_cnt [i*NWAY_W +: NWAY_W] = (way_hit[i])? {NWAY_W{1'b1}} : (mru[i*NWAY_W +: NWAY_W] > mru_index [N_WAYS]) ? mru[i*NWAY_W +: NWAY_W] - 1 : mru[i*NWAY_W +: NWAY_W];// the MRU way gets updated to the the highest value; the remaining, if their value was bigger than the MRU index previous value (mru_index), they get decremented

                //LRU - Decoder (checks every index in search for the lowest (0)
                assign way_select [i] = ~(|mru[i*NWAY_W +: NWAY_W]); //selects the way that has the lowest priority (mru = 0)              
             end
           
           
           assign mru_in = (|way_hit)? mru_cnt : mru_out; //If an hit occured, then it updates, to avoid updating during a (write) miss (mru_cnt would decrement every way besides the lowest)
           
           
           //Most Recently Used (MRU) memory	   
           iob_reg_file
             #(
               .ADDR_WIDTH (LINE_OFF_W),		
               .COL_WIDTH (N_WAYS*NWAY_W),
               .NUM_COL (1)
               ) 
           mru_memory //simply uses the same format as valid memory
             (
              .clk  (clk      ),
              .rst  (reset    ),
              .wdata(mru_in   ),
              .rdata(mru_out  ),			             
              .addr (line_addr),
              .en   (write_en )
              );
           
        end // if (REP_POLICU == `LRU)
      else if (REP_POLICY == `PLRU_mru)
        begin

           wire [N_WAYS -1:0]      mru_in, mru_out;

           //pseudo LRU MRU based Encoder (More Recenty-Used bits):
           assign mru_in = (&(mru_out | way_hit))? way_hit : mru_out | way_hit;//When the cache access results in a hi, it will update the MRU signal, if all ways were used, it resets and only updated the Most Recent
           
           // pseudo LRU MRU based Decoder:
           for (i = 1; i < N_WAYS; i=i+1)
             assign way_select [i] = ~mru_out[i] & (&mru_out[i-1:0]); //verifies priority (lower index)
           assign way_select[0] = ~mru_out[0];
           
           //Most Recently Used (MRU) memory	   
           iob_reg_file
             #(
               .ADDR_WIDTH (LINE_OFF_W),
               .COL_WIDTH (N_WAYS),
               .NUM_COL (1)
               ) 
           mru_memory //simply uses the same format as valid memory
             (
              .clk  (clk      ),
              .rst  (reset    ),
              .wdata(mru_in   ),
              .rdata(mru_out  ),			            
              .addr (line_addr),
              .en   (write_en )
              );

           
        end // if (REP_POLICY == PLRU_mru)
      else // (REP_POLICY == PLRU_tree)
        begin
           
           wire [N_WAYS -1: 1] tree_in, tree_out;
           wire [N_WAYS -1: 0] tree_dec [NWAY_W: 0]; // the order of the way line_addr will be [lower; ...; higher way line_addr], for readable reasons

           // Tree-structure: key_in[i] = tree's bit i (1 - upper half of the section, 0 -lower half)
           for (i = 1; i <= NWAY_W; i = i + 1)
	     for (j = 0; j < (1<<(i-1)) ; j = j + 1)
               begin : tree_encoder
	          assign tree_in [(1<<(i-1))+j] = (tree_out[(1<<(i-1))+j] && ~(|way_hit[N_WAYS-(2*j*(N_WAYS>>i)) -1: N_WAYS-(2*j+1)*(N_WAYS>>i)])) || (|way_hit[(N_WAYS-(2*j+1)*(N_WAYS>>i)) -1: N_WAYS-(2*j+2)*(N_WAYS>>i)]); // (t-bit * (~|way_hit[upper_section]) + |way_hit[lower_section])
	       end
           
           // Tree's Decoder: using the tree's bits, finds out where they are pointing in the binary tree.
           assign tree_dec [0] = {N_WAYS{1'b1}}; // the first position of the tree's matrix will be all 1s, for the AND logic of the following algorithm work properlly
           for (i = 1; i <= NWAY_W; i = i + 1)
	     for (j = 0; j < (1 << (i-1)); j = j + 1)
	       for (k = 0; k < (N_WAYS >> i); k = k + 1)
		 begin : tree_decoder
	            assign tree_dec [i][j*(N_WAYS >> (i-1)) + k] = tree_dec [i-1][j*(N_WAYS >> (i-1)) + k] && tree_out [(1 << (i-1)) + j]; // the first half will be the Tree's bit (1 equal upper position)
		    assign tree_dec [i][j*(N_WAYS >> (i-1)) + k + (N_WAYS >> i)] = tree_dec [i-1][j*(N_WAYS >> (i-1)) + k] && ~tree_out [(1 << (i-1)) + j]; //second half of the same Tree's bit (0 equals lower position)      
		 end


           
           // placing the way select wire in the correct order for the onehot-binary encoder
           for (i = 0; i < N_WAYS; i = i + 1)
	     assign way_select[i] = tree_dec [NWAY_W][N_WAYS - i -1];//the last row of tree_dec has the result of the Tree's encoder
           

           //Most Recently Used (MRU) memory	   
           iob_reg_file
             #(
               .ADDR_WIDTH (LINE_OFF_W),
               .COL_WIDTH (N_WAYS-1),
               .NUM_COL (1)
               ) 
           mru_memory //simply uses the same format as valid memory
             (
              .clk  (clk      ),
              .rst  (reset    ),
              .wdata(tree_in   ),
              .rdata(tree_out  ),     
              .addr (line_addr),
              .en   (write_en )
              );
           
        end // else: !if(REP_POLICY == PLRU_tree)
   endgenerate
   
endmodule
