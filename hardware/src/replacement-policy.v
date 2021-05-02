`timescale 1ns / 1ps
`include "iob-cache.vh"

/*--------------------*/
/* Replacement Policy */
/*--------------------*/
// Module that contains all iob-cache's replacement policies

module replacement_policy 
  #(
    parameter N_WAYS     = 8,
    parameter LINE_OFF_W = 0,
    parameter NWAY_W = $clog2(N_WAYS),
    parameter REP_POLICY = `PLRU_tree //LRU - Least Recently Used; PLRU_mru (1) - mru-based pseudoLRU; PLRU_tree (3) - tree-based pseudoLRU 
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
           
           
           wire [N_WAYS*NWAY_W -1:0] mru_out, mru_in;
           wire [N_WAYS*NWAY_W -1:0] mru; //Initial MRU values of the LRU algorithm, also initialized them in case it's the first access or was invalidated
           wire [N_WAYS*NWAY_W -1:0] mru_cnt; //updates the MRU line, the way used will be the highest value, while the others are decremented
           //wire [NWAY_W -1:0]        mru_index [N_WAYS :0]; //Index value of the MRU way
           wire [NWAY_W-1:0]         mru_index, way_hit_bin;
           
           onehot_to_bin #(
                           .BIN_W (NWAY_W)	       
                           ) 
           way_hit_binary
             (    
                  .onehot(way_hit[N_WAYS-1:1]),
                  .bin(way_hit_bin)
                  );

           
           assign mru_index [NWAY_W-1:0] = mru_out >> (NWAY_W*way_hit_bin);
           
           //assign mru_index [0] [NWAY_W -1:0] = {NWAY_W{1'b0}}; 
           
           for (i = 0; i < N_WAYS; i=i+1)
	     begin : encoder_decoder
                //LRU - Encoder
	        assign mru [i*NWAY_W +: NWAY_W] = (|mru_out)? mru_out [i*NWAY_W +: NWAY_W] : i; //verifies if the mru line has been initialized (if any bit in mru_output is HIGH), otherwise applies the priority values
                //assign mru_index [i+1][NWAY_W -1:0]  = mru_index[i][NWAY_W-1:0] | ({NWAY_W{way_hit[i]}} & mru[(i+1)*NWAY_W -1: i*NWAY_W]); //stores the  index-value of the MRU way
                //assign mru_cnt [i*NWAY_W +: NWAY_W] = (way_hit[i])? {NWAY_W{1'b1}} : (mru[i*NWAY_W +: NWAY_W] > mru_index [N_WAYS]) ? mru[i*NWAY_W +: NWAY_W] - 1 : mru[i*NWAY_W +: NWAY_W];// the MRU way gets updated to the the highest value; the remaining, if their value was bigger than the MRU index previous value (mru_index), they get decremented
                assign mru_cnt [i*NWAY_W +: NWAY_W] = (way_hit[i])? {NWAY_W{1'b1}} : (mru[i*NWAY_W +: NWAY_W] > mru_index) ? mru[i*NWAY_W +: NWAY_W] - 1 : mru[i*NWAY_W +: NWAY_W];// the MRU way gets updated to the the highest value; the remaining, if their value was bigger than the MRU index previous value (mru_index), they get decremented

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


           onehot_to_bin #(
                           .BIN_W (NWAY_W)	       
                           ) 
           onehot_bin
             (    
                  .onehot(way_select[N_WAYS-1:1]),
                  .bin(way_select_bin)
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


           onehot_to_bin #(
                           .BIN_W (NWAY_W)	       
                           ) 
           onehot_bin
             (    
                  .onehot(way_select[N_WAYS-1:1]),
                  .bin(way_select_bin)
                  );
           
        end // if (REP_POLICY == PLRU_mru)
      else // (REP_POLICY == PLRU_tree)
        begin
           /*
            i: tree level, start from 1, i <= NWAY_W
            j: tree node id @ i level, start from 0, j < (1<<(i-1))
            (((1<<(i-1))+j)*2)*(1<<(NWAY_W-i))   ==> start node id of left tree @ the lowest level node pointed to
            (((1<<(i-1))+j)*2+1)*(1<<(NWAY_W-i)) ==> start node id of right tree @ the lowest level node pointed to

            way_hit[(((1<<(i-1))+j)*2)*(1<<(NWAY_W-i))-N_WAYS +: (N_WAYS>>i)]   ==> way hit range of left tree
            way_hit[(((1<<(i-1))+j)*2+1)*(1<<(NWAY_W-i))-N_WAYS +: (N_WAYS>>i)] ==> way hit range of right tree


            == tree traverse ==

                         <--0     1-->                 traverse direction
                              [1]                      node id @ level1
                    [2]                 [3]            node id @ level2 ==> which to traverse? from node_id[1]
               [4]       [5]       [6]       [7]       node id @ level3 ==> which to traverse? from node_id[2]
            [08] [09] [10] [11] [12] [13] [14] [15]    node id @ level4 ==> which to traverse? from node_id[3]
            (00) (01) (02) (03) (04) (05) (06) (07)    way idx

            node value is 0 -> left tree traverse
            node value is 1 -> right tree traverse

            node id mapping to way idx: node_id[NWAY_W]-N_WAYS
            */

           // wire [N_WAYS-1:1] t_plru, t_plru_output;
           wire [N_WAYS -1: 1] tree_in, tree_out;
           wire [NWAY_W:0]     node_id[NWAY_W:1];
           assign node_id[1] = tree_out[1] ? 3 : 2; // next node id @ level2 to traverse
           for (i = 2; i <= NWAY_W; i = i + 1) begin : traverse_tree_level
              // next node id @ level3, level4, ..., to traverse
              assign node_id[i] = tree_out[node_id[i-1]] ? ((node_id[i-1]<<1)+1) : (node_id[i-1]<<1);
           end

           for (i = 1; i <= NWAY_W; i = i + 1) begin : tree_level
              for (j = 0; j < (1<<(i-1)); j = j + 1) begin : tree_level_node
                 assign tree_in[(1<<(i-1))+j] = ~(|way_hit) ? tree_out[(1<<(i-1))+j] :
                                                (|way_hit[((((1<<(i-1))+j)*2)*(1<<(NWAY_W-i)))-N_WAYS +: (N_WAYS>>i)]) ||
                                                (tree_out[(1<<(i-1))+j] && (~(|way_hit[((((1<<(i-1))+j)*2+1)*(1<<(NWAY_W-i)))-N_WAYS +: (N_WAYS>>i)])));
              end
           end

           assign way_select_bin = node_id[NWAY_W]-N_WAYS;
           assign way_select = (1 << way_select_bin);

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
              .wdata(tree_in      ),
              .rdata(tree_out     ),
              .addr (line_addr    ),
              .en   (write_en     )
              );
        end

   endgenerate
   
endmodule
