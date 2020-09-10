`timescale 1ns / 1ps
`include "iob-cache.vh"

module cache_memory
  #(
    //memory cache's parameters
    parameter FE_ADDR_W   = 32,       //Address width - width that will used for the cache 
    parameter FE_DATA_W   = 32,       //Data width - word size used for the cache
    parameter N_WAYS   = 1,        //Number of Cache Ways
    parameter LINE_OFF_W  = 6,      //Line-Offset Width - 2**NLINE_W total cache lines
    parameter WORD_OFF_W = 3,       //Word-Offset Width - 2**OFFSET_W total FE_DATA_W words per line 
    //Do NOT change - memory cache's parameters - dependency
    parameter NWAY_W   = $clog2(N_WAYS), //Cache Ways Width
    parameter FE_NBYTES  = FE_DATA_W/8,      //Number of Bytes per Word
    parameter FE_BYTE_W = $clog2(FE_NBYTES), //Offset of the Number of Bytes per Word
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTE_W = $clog2(BE_NBYTES), //Offset of the Number of Bytes per Word
    //Do NOT change - slave parameters - dependency
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W), //burst offset based on the cache and memory word size
    parameter WTBUF_DEPTH_W = 4,
    //Replacement policy (N_WAYS > 1)
    parameter REP_POLICY = `LRU //LRU - Least Recently Used (stack/shift); LRU_add (1) - LRU with adders ; BIT_PLRU (2) - bit-based pseudoLRU; TREE_PLRU (3) - tree-based pseudoLRU
    )
   ( 
     input                                      clk,
     input                                      reset,
     //front-end
     input                                      valid,
     input [FE_ADDR_W-1:FE_BYTE_W]              addr,
     input [FE_DATA_W-1:0]                      wdata,
     input [FE_NBYTES-1:0]                      wstrb,
     output [FE_DATA_W-1:0]                     rdata,
     output                                     ready,
     //stored input value
     input                                      valid_reg,
     input [FE_ADDR_W-1:FE_BYTE_W]              addr_reg,
     input [FE_DATA_W-1:0]                      wdata_reg,
     input [FE_NBYTES-1:0]                      wstrb_reg,
     output [FE_DATA_W-1:0]                     rdata_reg,
     //back-end write-channel
     output                                     write_valid,
     output [FE_ADDR_W-1:FE_BYTE_W]             write_addr,
     output [FE_DATA_W-1:0]                     write_wdata,
     output [FE_NBYTES-1:0]                     write_wstrb,
     input                                      write_ready,
     //back-end read-channel
     output                                     replace_valid,
     output [FE_ADDR_W -1:BE_BYTE_W+LINE2MEM_W] replace_addr,
     input                                      replace_ready,
     input                                      read_valid,
     input [LINE2MEM_W-1:0]                     read_addr,
     input [BE_DATA_W-1:0]                      read_rdata,
     //cache-control
     input                                      invalidate,
     output                                     wtbuf_full,
     output                                     wtbuf_empty,
     output                                     write_hit,
     output                                     write_miss,
     output                                     read_hit,
     output                                     read_miss
     );

   
   localparam TAG_W = FE_ADDR_W - (FE_BYTE_W + WORD_OFF_W + LINE_OFF_W);

   wire                                         hit;
      
   //cache-memory internal signals
   wire [N_WAYS-1:0]                            way_hit, way_select;
   
   wire [TAG_W-1:0]                             tag    = addr_reg[FE_ADDR_W-1       -:TAG_W]; //so the tag doesnt update during ready on a read-access, losing the current hit status (can take the 1 clock-cycle delay)
   wire [LINE_OFF_W-1:0]                        index  = addr    [FE_ADDR_W-TAG_W-1 -:LINE_OFF_W];//cant wait, doesnt update during a write-access
   wire [WORD_OFF_W-1:0]                        offset = addr_reg[FE_BYTE_W         +:WORD_OFF_W]; //so the offset doesnt update during ready on a read-access (can take the 1 clock-cycle delay)
   
   
   wire [N_WAYS*(2**WORD_OFF_W)*FE_DATA_W-1:0]  line_rdata;
   wire [N_WAYS*TAG_W-1:0]                      line_tag;
   wire [N_WAYS-1:0]                            line_v;
   reg [N_WAYS-1:0]                             v;

   always @ (posedge clk)
     v <= line_v;
  
   
   reg [(2**WORD_OFF_W)*FE_NBYTES-1:0]          line_wstrb;
   
   wire                                         write_access = |wstrb & valid; //front-end doesn't update in the same clock-cycle ready is asserted, during an write-access
   wire                                         write_access_reg = |wstrb_reg & valid_reg;
   wire                                         read_access = ~|wstrb & valid; //front-end updates in the same clock-cycle ready is asserted
   wire                                         read_access_reg = ~|wstrb_reg & valid_reg;//signal mantains the access 1 addition clock-cycle after ready is asserted 

   
   //back-end write channel
   wire                                         buffer_empty, buffer_full;   
   wire [FE_NBYTES+(FE_ADDR_W-FE_BYTE_W)+(FE_DATA_W) -1 :0] buffer_dout;
   
   assign write_valid = ~buffer_empty;
   assign write_addr  = buffer_dout[FE_NBYTES + FE_DATA_W +: FE_ADDR_W - FE_BYTE_W];
   assign write_wdata = buffer_dout[FE_NBYTES             +: FE_DATA_W            ];
   assign write_wstrb = buffer_dout[0                     +: FE_NBYTES            ];

   assign wtbuf_full = buffer_full;
   assign wtbuf_empty = buffer_empty & write_ready & ~write_valid;
   

   iob_async_fifo #(
		    .DATA_WIDTH    (FE_ADDR_W-FE_BYTE_W + FE_DATA_W + FE_NBYTES),
		    .ADDRESS_WIDTH (WTBUF_DEPTH_W)
		    ) 
   write_throught_buffer 
     (
      .rst     (reset),       
      .data_out(buffer_dout), 
      .empty   (buffer_empty),
      .level_r (),
      .read_en (write_ready),
      .rclk    (clk),    
      .data_in ({addr_reg,wdata_reg,wstrb_reg}), 
      .full    (buffer_full),
      .level_w (),
      .write_en(write_access & ready),
      .wclk    (clk)
      );

   //back-end read channel
   assign replace_valid = (~hit & read_access_reg & replace_ready) & (buffer_empty & write_ready);
   assign replace_addr  = addr[FE_ADDR_W -1:BE_BYTE_W+LINE2MEM_W];


   //front-end READY signal
   assign ready = (hit & (read_access_reg) & (replace_ready)) | (~buffer_full & (write_access_reg));
   //assign ready = (hit & (read_access_reg & (~write_access)) & (replace_ready & (~replace_valid))) | (~buffer_full & (write_access_reg));
   // read section needs to be the registered, so it doesn't change the moment ready asserts and updates the input. Write doesn't update on the same cycle as ready asserts, and in the next clock cycle, will have the next input.

   
   genvar                                                   i,j,k;
   generate
      if (LINE2MEM_W > 0)
        begin
           if(N_WAYS != 1)
             begin
                wire [NWAY_W-1:0] way_hit_bin, way_select_bin;//reason for the 2 generates for single vs multiple ways

                assign hit = |way_hit;
                
                replacement_process #(
	                              .N_WAYS    (N_WAYS    ),
	                              .LINE_OFF_W(LINE_OFF_W),
                                      .REP_POLICY(REP_POLICY)
	                              )
                replacement_policy_algorithm
                  (
                   .clk       (clk             ),
                   .reset     (reset|invalidate),
                   .write_en  (ready        ),
                   .way_hit   (way_hit         ),
                   .line_addr (addr_reg[FE_ADDR_W-TAG_W-1 -:LINE_OFF_W] ),
                   .way_select(way_select      ),
                   .way_select_bin(way_select_bin)
                   );
                
                onehot_to_bin #(
                                .BIN_W (NWAY_W)
                                ) 
                way_hit_encoder
                  (
                   .onehot(way_hit[N_WAYS-1:1]),
                   .bin   (way_hit_bin)
                   );

                
                //Read Data Multiplexer

                assign rdata [FE_DATA_W-1:0] = line_rdata >> FE_DATA_W*(offset + (2**WORD_OFF_W)*way_hit_bin);
                
                
                //Cache Line Write Strobe Shifter
                always @*
                  if(~replace_ready)
                    line_wstrb = {BE_NBYTES{read_valid}} << (read_addr*BE_NBYTES); //line-replacement
                  else
                    line_wstrb = (wstrb_reg) << (offset*FE_NBYTES);


                
                for (k = 0; k < N_WAYS; k=k+1)
                  begin : line_way
                     for(j = 0; j < 2**LINE2MEM_W; j=j+1)
                       begin : line_word_number
                          for(i = 0; i < BE_DATA_W/FE_DATA_W; i=i+1)
                            begin : line_word_width
                               iob_gen_sp_ram
                                  #(
                                    .DATA_W(FE_DATA_W),
                                    .ADDR_W(LINE_OFF_W)
                                    )
                               cache_memory 
                                  (
                                   .clk (clk),
                                   .en  (valid), 
                                   .we ({FE_NBYTES{way_hit[k]}} & line_wstrb[(j*(BE_DATA_W/FE_DATA_W)+i)*FE_NBYTES +: FE_NBYTES]),
                                   .addr(index),
                                   .data_in ((~replace_ready)? read_rdata[i*FE_DATA_W +: FE_DATA_W] : wdata),
                                   .data_out(line_rdata[(k*(2**WORD_OFF_W)+j*(BE_DATA_W/FE_DATA_W)+i)*FE_DATA_W +: FE_DATA_W])
                                   );
                            end // for (i = 0; i < 2**WORD_OFF_W; i=i+1)
                       end // for (j = 0; j < 2**LINE2MEM_W; j=j+1)

                    
                     iob_reg_file
                       #(
                         .ADDR_WIDTH(LINE_OFF_W), 
                         .COL_WIDTH (1),
                         .NUM_COL   (1)
	                 ) 
	             valid_memory 
	               (
	                .clk  (clk                          ),
	                .rst  (reset|invalidate             ),
	                .wdata(replace_valid                ),				       
	                .addr (index                    ),
	                .en   (way_select[k] & replace_valid),
	                .rdata(line_v[k]                    )   
	                );

                  /*     iob_sp_ram
                       #(
                         .DATA_W(1),
                         .ADDR_W(LINE_OFF_W)
                         )
                     valid_memory 
                       (
                        .clk (clk                           ),
                        .en  (valid                         ), 
                        .we  (way_select[k] & replace_valid ),
                        .addr (index                        ),
                        .data_in (1'b1                       ),
                        .data_out(v[k])
                        );
        */             
                     iob_sp_ram
                       #(
                         .DATA_W(TAG_W),
                         .ADDR_W(LINE_OFF_W)
                         )
                     tag_memory 
                       (
                        .clk (clk                           ),
                        .en  (valid                         ), 
                        .we  (way_select[k] & replace_valid),
                        .addr (index                        ),
                        .data_in (tag                       ),
                        .data_out(line_tag[TAG_W*k +: TAG_W])
                        );



                     
                     //Cache hit signal that indicates which way has had the hit
                     assign way_hit[k] = (tag == line_tag[TAG_W*k +: TAG_W]) & v[k]; 
                     
                  end // block: line_way
                
             end // if (N_WAYS != 1)
        end // if (LINE2MEM_W > 0)
   endgenerate

endmodule










/*---------------------------*/
/* One-Hot to Binary Encoder */
/*---------------------------*/

// One-hot to binary encoder (if input is (0)0 or (0)1, the output is 0)
module onehot_to_bin 
  #(
    parameter BIN_W = 2
    )
   (
    input [2**BIN_W-1:1]   onehot,
    output reg [BIN_W-1:0] bin 
    );
   always @ (onehot) begin: onehot_to_binary_encoder
      integer i;
      reg [BIN_W-1:0] bin_cnt ;
      bin_cnt = 0;
      for (i=1; i<2**BIN_W; i=i+1)
        if (onehot[i]) bin_cnt = bin_cnt|i;
      bin = bin_cnt;    
   end
endmodule  // onehot_to_bin



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

module iob_gen_sp_ram #(
                        parameter DATA_W = 32,
                        parameter ADDR_W = 10
                        )  
   (                
                    input                clk,
                    input                en, 
                    input [DATA_W/8-1:0] we, 
                    input [ADDR_W-1:0]   addr,
                    output [DATA_W-1:0]  data_out,
                    input [DATA_W-1:0]   data_in
                    );

   genvar                                i;
   generate
      for (i = 0; i < (DATA_W/8); i = i + 1)
        begin : ram
           iob_sp_ram
               #(
                 .DATA_W(8),
                 .ADDR_W(ADDR_W)
                 )
           iob_cache_mem
               (
                .clk (clk),
                .en  (en),
                .we  (we[i]),
                .addr(addr),
                .data_out(data_out[8*i +: 8]),
                .data_in (data_in [8*i +: 8])
                );
        end
   endgenerate

endmodule // iob_gen_sp_ram
