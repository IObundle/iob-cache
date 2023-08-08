`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"
`include "iob_cache_conf.vh"

module iob_cache_replacement_policy #(
   parameter N_WAYS     = 8,
   parameter NLINES_W   = 0,
   parameter NWAYS_W    = $clog2(N_WAYS),
   parameter REP_POLICY = `IOB_CACHE_PLRU_TREE
) (
   input                 clk_i,
   input                 cke_i,
   input                 reset_i,
   input                 write_en_i,
   input  [  N_WAYS-1:0] way_hit_i,
   input  [NLINES_W-1:0] line_addr_i,
   output [  N_WAYS-1:0] way_select_o,
   output [ NWAYS_W-1:0] way_select_bin_o
);

   genvar i, j, k;

   generate
      if (REP_POLICY == `IOB_CACHE_LRU) begin : g_LRU
         wire [N_WAYS*NWAYS_W-1:0] mru_out, mru_in;
         wire [N_WAYS*NWAYS_W-1:0] mru; // Initial MRU values of the LRU algorithm, also initialized them in case it's the first access or was invalidated
         wire [N_WAYS*NWAYS_W-1:0] mru_cnt; // updates the MRU line, the way used will be the highest value, while the others are decremented
         wire [NWAYS_W-1:0] mru_index, way_hit_bin;

         iob_cache_onehot_to_bin #(NWAYS_W) way_hit_binary (
            .onehot_i(way_hit_i[N_WAYS-1:1]),
            .bin_o   (way_hit_bin)
         );

         assign mru_index[NWAYS_W-1:0] = mru_out >> (NWAYS_W * way_hit_bin);

         for (i = 0; i < N_WAYS; i = i + 1) begin : encoder_decoder
            // LRU - Encoder
            assign mru [i*NWAYS_W +: NWAYS_W] = (|mru_out)? mru_out [i*NWAYS_W +: NWAYS_W] : i; // verifies if the mru line has been initialized (if any bit in mru_output is HIGH), otherwise applies the priority values
            assign mru_cnt [i*NWAYS_W +: NWAYS_W] = (way_hit_i[i])? {NWAYS_W{1'b1}} : (mru[i*NWAYS_W +: NWAYS_W] > mru_index) ? mru[i*NWAYS_W +: NWAYS_W] - 1 : mru[i*NWAYS_W +: NWAYS_W]; // the MRU way gets updated to the the highest value; the remaining, if their value was bigger than the MRU index previous value (mru_index), they get decremented

            // LRU - Decoder (checks every index in search for the lowest (0)
            assign way_select_o [i] = ~(|mru[i*NWAYS_W+:NWAYS_W]); // selects the way that has the lowest priority (mru = 0)
         end

         assign mru_in = (|way_hit_i)? mru_cnt : mru_out; // If an hit occured, then it updates, to avoid updating during a (write) miss (mru_cnt would decrement every way besides the lowest)

         // Most Recently Used (MRU) memory
         iob_regfile_sp #(
            .ADDR_W(NLINES_W),
            .DATA_W(N_WAYS * NWAYS_W)
         ) mru_memory  // simply uses the same format as valid memory
         (
            .clk_i(clk_i),
            .cke_i(cke_i),
            .arst_i(reset_i),

            .rst_i(1'b0),
            .we_i(write_en_i),
            .addr_i(line_addr_i),
            .d_i(mru_in),
            .d_o(mru_out)
         );

         iob_cache_onehot_to_bin #(NWAYS_W) onehot_bin (
            .onehot_i(way_select_o[N_WAYS-1:1]),
            .bin_o   (way_select_bin_o)
         );
      end else if (REP_POLICY == `IOB_CACHE_PLRU_MRU) begin : g_PLRU_MRU
         wire [N_WAYS -1:0] mru_in, mru_out;

         // pseudo LRU MRU based Encoder (More Recenty-Used bits):
         assign mru_in = (&(mru_out | way_hit_i))? way_hit_i : mru_out | way_hit_i; // When the cache access results in a hi, it will update the MRU signal, if all ways were used, it resets and only updated the Most Recent

         // pseudo LRU MRU based Decoder:
         for (i = 1; i < N_WAYS; i = i + 1) begin : g_way_select_block
            assign way_select_o[i] = ~mru_out[i] & (&mru_out[i-1:0]);  // verifies priority (lower index)
         end
         assign way_select_o[0] = ~mru_out[0];

         // Most Recently Used (MRU) memory
         iob_regfile_sp #(
            .ADDR_W(NLINES_W),
            .DATA_W(N_WAYS)
         ) mru_memory  // simply uses the same format as valid memory
         (
            .clk_i(clk_i),
            .cke_i(cke_i),
            .arst_i(reset_i),

            .rst_i(1'b0),
            .we_i(write_en_i),
            .addr_i(line_addr_i),
            .d_i(mru_in),
            .d_o(mru_out)
         );

         iob_cache_onehot_to_bin #(NWAYS_W) onehot_bin (
            .onehot_i(way_select_o[N_WAYS-1:1]),
            .bin_o   (way_select_bin_o)
         );
      end else begin : g_PLRU_TREE
         // (REP_POLICY == PLRU_TREE)
         /*
            i: tree level, start from 1, i <= NWAYS_W
            j: tree node id @ i level, start from 0, j < (1<<(i-1))
            (((1<<(i-1))+j)*2)*(1<<(NWAYS_W-i))   ==> start node id of left tree @ the lowest level node pointed to
            (((1<<(i-1))+j)*2+1)*(1<<(NWAYS_W-i)) ==> start node id of right tree @ the lowest level node pointed to

            way_hit_i[(((1<<(i-1))+j)*2)*(1<<(NWAYS_W-i))-N_WAYS +: (N_WAYS>>i)]   ==> way hit range of left tree
            way_hit_i[(((1<<(i-1))+j)*2+1)*(1<<(NWAYS_W-i))-N_WAYS +: (N_WAYS>>i)] ==> way hit range of right tree


            == tree traverse ==

                         <--0     1-->                 traverse direction
                              [1]                      node id @ level1
                    [2]                 [3]            node id @ level2 ==> which to traverse? from node_id[1]
               [4]       [5]       [6]       [7]       node id @ level3 ==> which to traverse? from node_id[2]
            [08] [09] [10] [11] [12] [13] [14] [15]    node id @ level4 ==> which to traverse? from node_id[3]
            (00) (01) (02) (03) (04) (05) (06) (07)    way idx

            node value is 0 -> left tree traverse
            node value is 1 -> right tree traverse

            node id mapping to way idx: node_id[NWAYS_W]-N_WAYS
            */

         wire [N_WAYS -1:1] tree_in, tree_out;
         wire [NWAYS_W:0] node_id[NWAYS_W:1];
         assign node_id[1] = tree_out[1] ? 3 : 2;  // next node id @ level2 to traverse
         for (i = 2; i <= NWAYS_W; i = i + 1) begin : g_traverse_tree_level
            // next node id @ level3, level4, ..., to traverse
            assign node_id[i] = tree_out[node_id[i-1]] ? ((node_id[i-1]<<1)+1) : (node_id[i-1]<<1);
         end

         for (i = 1; i <= NWAYS_W; i = i + 1) begin : tree_level
            for (j = 0; j < (1 << (i - 1)); j = j + 1) begin : tree_level_node
               assign tree_in[(1<<(i-1))+j] = ~(|way_hit_i) ? tree_out[(1<<(i-1))+j] :
                                                (|way_hit_i[((((1<<(i-1))+j)*2)*(1<<(NWAYS_W-i)))-N_WAYS +: (N_WAYS>>i)]) ||
                                                (tree_out[(1<<(i-1))+j] && (~(|way_hit_i[((((1<<(i-1))+j)*2+1)*(1<<(NWAYS_W-i)))-N_WAYS +: (N_WAYS>>i)])));
            end
         end

         assign way_select_bin_o = node_id[NWAYS_W] - N_WAYS;
         assign way_select_o     = (1 << way_select_bin_o);

         // Most Recently Used (MRU) memory
         iob_regfile_sp #(
            .ADDR_W(NLINES_W),
            .DATA_W(N_WAYS - 1)
         ) mru_memory  // simply uses the same format as valid memory
         (
            .clk_i(clk_i),
            .cke_i(cke_i),
            .arst_i(reset_i),

            .rst_i(1'b0),
            .we_i(write_en_i),
            .addr_i(line_addr_i),
            .d_i(tree_in),
            .d_o(tree_out)
         );
      end
   endgenerate

endmodule
