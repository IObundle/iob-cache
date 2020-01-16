`timescale 1ns / 1ps
`include "iob-cache.vh"

module iob_cache 
  #(
    parameter ADDR_W   = 32,
    parameter DATA_W   = 32,
    parameter N_BYTES  = DATA_W/8,
    parameter NLINE_W  = 4,
    parameter OFFSET_W = 2,
`ifdef L1
    parameter I_NLINE_W = 3,
    parameter I_OFFSET_W = 2,
`endif
`ifdef ASSOC_CACHE
    parameter NWAY_W   = 2,
`endif
    parameter WTBUF_DEPTH_W = 4
    ) 
   (
    input                    clk,
    input                    reset,
    input [DATA_W-1:0]       cache_write_data,
    input [N_BYTES-1:0]      cache_wstrb,
    input [ADDR_W-1:2]       cache_addr,
    output [DATA_W-1:0]      cache_read_data,
    input                    cpu_req,
    output                   cache_ack,

    // cache controller signals  
    input [`CTRL_ADDR_W-1:0] cache_ctrl_address,
    output [DATA_W-1:0]      cache_ctrl_requested_data,
    input                    cache_ctrl_cpu_request,
    output                   cache_ctrl_acknowledge,
    input                    cache_ctrl_instr_access, 

    // AXI interface 
    // Address Write
    output [0:0]             AW_ID, 
    output [ADDR_W-1:0]      AW_ADDR,
    output [7:0]             AW_LEN,
    output [2:0]             AW_SIZE,
    output [1:0]             AW_BURST,
    output [0:0]             AW_LOCK,
    output [3:0]             AW_CACHE,
    output [2:0]             AW_PROT,
    output [3:0]             AW_QOS,
    output                   AW_VALID,
    input                    AW_READY,
    //Write
    output [DATA_W-1:0]      W_DATA,
    output [N_BYTES-1:0]     W_STRB,
    output                   W_LAST,
    output                   W_VALID, 
    input                    W_READY,
    input [0:0]              B_ID,
    input [1:0]              B_RESP,
    input                    B_VALID,
    output                   B_READY,
    //Address Read
    output [0:0]             AR_ID,
    output [ADDR_W-1:0]      AR_ADDR, 
    output [7:0]             AR_LEN,
    output [2:0]             AR_SIZE,
    output [1:0]             AR_BURST,
    output [0:0]             AR_LOCK,
    output [3:0]             AR_CACHE,
    output [2:0]             AR_PROT,
    output [3:0]             AR_QOS,
    output                   AR_VALID, 
    input                    AR_READY,
    //Read
    input [0:0]              R_ID,
    input [DATA_W-1:0]       R_DATA,
    input [1:0]              R_RESP,
    input                    R_LAST, 
    input                    R_VALID, 
    output                   R_READY  	      
    );
   
   // parameter TAG_W = ADDR_W - (NLINE_W + 2 + OFFSET_W);
   
   wire			     data_load;
   wire [OFFSET_W-1 :0]      select_counter;
   wire 		     buffer_full, buffer_empty;
   wire 		     cache_invalidate;
   wire [`CTRL_COUNTER_W-1:0] ctrl_counter;
   wire 		      write_enable; //Enables the write in memories like Data (still depends on the wstrb) and algorithm's (it goes high at the end of the task, after all procedures have concluded)


`ifdef ASSOC_CACHE
   wire [2**NWAY_W -1: 0]     cache_hit;//uses one-hot numenclature
`else 
   wire 		      cache_hit;
`endif
`ifdef L1
   wire 		      instr_req = cache_ctrl_instr_access;
`endif
   
   wire 		      cache_write = cpu_req & (|cache_wstrb);
   wire 		      cache_read = cpu_req & ~(|cache_wstrb);  

   wire 		      cache_read_miss;
   wire 		      read_verification;
   
   
   cache_verification_controller #(
				   )
   verification_FSM
     (
      .clk (clk),
      .reset (reset),
      .cpu_req (cpu_req),
      .cache_write (cache_write),
      .cache_read (cache_read),
      .data_load (data_load),
`ifdef ASSOC_CACHE
      .cache_hit (|cache_hit),
`else
      .cache_hit (cache_hit),
`endif
      .buffer_full (buffer_full),
      .buffer_empty (buffer_empty),
      .instr_access (cache_ctrl_instr_access),
      .cache_ack (cache_ack),
      .write_enable (write_enable),
      .ctrl_counter (ctrl_counter),
      .cache_read_miss (cache_read_miss),
      .cache_read_verification (read_verification)
      );
   

   memory_cache #(
`ifdef L1
		  .I_NLINE_W  (I_NLINE_W),
		  .I_OFFSET_W (I_OFFSET_W),
`endif
`ifdef ASSOC_CACHE
		  .NWAY_W   (NWAY_W),
`endif
		  .ADDR_W   (ADDR_W),
                  .DATA_W   (DATA_W),
                  .N_BYTES  (N_BYTES),
		  .NLINE_W  (NLINE_W),
		  .OFFSET_W (OFFSET_W)
		  )
   memory_cache		  
     (
      .clk   (clk),
      .reset (reset),
      .cache_write_data (cache_write_data),
      .cache_wstrb      (cache_wstrb),
      .cache_addr       (cache_addr),
      .cache_read_data  (cache_read_data),
      .cpu_req          (cpu_req),
      .cache_read_miss  (cache_read_miss),
      .data_load        (data_load),
      .select_counter   (select_counter),
      .buffer_empty     (buffer_empty),
      .buffer_full      (buffer_full),
      .cache_invalidate (cache_invalidate),
      .write_enable     (write_enable),
      .cache_hit_output (cache_hit),
`ifdef L1
      .instr_req        (instr_req),
`endif
      .R_DATA  (R_DATA),
      .R_READY (R_READY)
      );
   


   
   write_through_ctrl #(              
				      .ADDR_W (ADDR_W),
				      .DATA_W (DATA_W),
				      .N_BYTES (N_BYTES),
				      .WTBUF_DEPTH_W (WTBUF_DEPTH_W)
				      ) 
   write_through_ctrl
     (
      .clk         (clk),
      .reset       (reset),
      .cpu_req     (cpu_req),
      .cache_addr  (cache_addr),
      .cache_wstrb (cache_wstrb),
      .cache_wdata (cache_write_data),
      .buffer_empty (buffer_empty),
      .buffer_full  (buffer_full),     
      .AW_ID    (AW_ID), 
      .AW_ADDR  (AW_ADDR),
      .AW_LEN   (AW_LEN),
      .AW_SIZE  (AW_SIZE),
      .AW_BURST (AW_BURST),
      .AW_LOCK  (AW_LOCK),
      .AW_CACHE (AW_CACHE),
      .AW_PROT  (AW_PROT),
      .AW_QOS   (AW_QOS),
      .AW_VALID (AW_VALID),
      .AW_READY (AW_READY),
      .W_DATA   (W_DATA),
      .W_STRB   (W_STRB),
      .W_LAST   (W_LAST),
      .W_VALID  (W_VALID), 
      .W_READY  (W_READY),
      .B_ID     (B_ID),
      .B_RESP   (B_RESP),
      .B_VALID  (B_VALID),
      .B_READY  (B_READY)    
      );



   line_loader_ctrl #(
`ifdef L1
                      .I_OFFSET_W (I_OFFSET_W),
`endif
                      .ADDR_W (ADDR_W),
                      .DATA_W (DATA_W),
                      .N_BYTES (N_BYTES),
                      .OFFSET_W (OFFSET_W)
                      )
   line_loader_ctrl (
                     .clk               (clk),
                     .reset             (reset),
`ifdef L1
                     .instr_req         (instr_req),
`endif
                     .cache_addr        (cache_addr[ADDR_W-1: OFFSET_W+2]),
                     .read_verification (read_verification), 
`ifdef ASSOC_CACHE
                     .cache_miss        (~(|cache_hit)),
`else
		     .cache_miss (~cache_hit),
`endif
                     .buffer_empty      (buffer_empty),
                     .data_load      (data_load),
                     .select_counter (select_counter), 
                     .AR_ID    (AR_ID),
                     .AR_ADDR  (AR_ADDR), 
                     .AR_LEN   (AR_LEN),
                     .AR_SIZE  (AR_SIZE),
                     .AR_BURST (AR_BURST),
                     .AR_LOCK  (AR_LOCK),
                     .AR_CACHE (AR_CACHE),
                     .AR_PROT  (AR_PROT),
                     .AR_QOS   (AR_QOS),
                     .AR_VALID (AR_VALID), 
                     .AR_READY (AR_READY),
                     .R_ID     (R_ID),
                     .R_RESP   (R_RESP),
                     .R_LAST   (R_LAST), 
                     .R_VALID  (R_VALID), 
                     .R_READY  (R_READY)
                     );
   
   
   
   
   cache_controller #(
		      .DATA_W(DATA_W)
		      )
   cache_ctrl
     (
      .clk (clk),   
      .ctrl_counter_input (ctrl_counter             ),
      .ctrl_cache_invalid (cache_invalidate         ),
      .ctrl_addr          (cache_ctrl_address       ),
      .ctrl_req_data      (cache_ctrl_requested_data),
      .ctrl_cpu_req       (cache_ctrl_cpu_request   ),
      .ctrl_ack           (cache_ctrl_acknowledge   ),
      .ctrl_reset         (reset                    ),
      .ctrl_buffer_state  ({buffer_full,buffer_empty})
      );
   

   
endmodule // iob_cache


module cache_controller #(
			  parameter DATA_W = 32
			  )
   (
    input                       clk,
    input [`CTRL_COUNTER_W-1:0] ctrl_counter_input, 
    output reg                  ctrl_cache_invalid,
    input [`CTRL_ADDR_W-1:0]    ctrl_addr,
    output reg [DATA_W-1:0]     ctrl_req_data,
    input                       ctrl_cpu_req,
    output reg                  ctrl_ack,
    input                       ctrl_reset, 
    input [1:0]                 ctrl_buffer_state
    );

   reg [DATA_W-1:0]             instr_hit_cnt, instr_miss_cnt;
   reg [DATA_W-1:0]             data_read_hit_cnt, data_read_miss_cnt, data_write_hit_cnt, data_write_miss_cnt;
   reg [DATA_W-1:0]             data_hit_cnt, data_miss_cnt; 
   reg [DATA_W-1:0]             cache_hit_cnt, cache_miss_cnt;
   reg 				ctrl_counter_reset;
   
`ifdef CTRL_CLK
   reg [2*DATA_W-1:0]           ctrl_clk_cnt;
   reg 				ctrl_clk_start;
`endif

   wire 			ctrl_arst = ctrl_reset | ctrl_counter_reset;
   
   always @ (posedge clk, posedge ctrl_arst)
     begin 		
	if (ctrl_arst) 
	  begin
	     instr_hit_cnt <= {DATA_W{1'b0}};
  	     instr_miss_cnt <= {DATA_W{1'b0}};
             data_read_hit_cnt <= {DATA_W{1'b0}};
	     data_read_miss_cnt <= {DATA_W{1'b0}};
	     data_write_hit_cnt <= {DATA_W{1'b0}};
	     data_write_miss_cnt <= {DATA_W{1'b0}};
	     data_hit_cnt <= {DATA_W{1'b0}};
	     data_miss_cnt <= {DATA_W{1'b0}};
	     cache_hit_cnt <= {DATA_W{1'b0}};
	     cache_miss_cnt <= {DATA_W{1'b0}}; 
          end 
	else
	  begin
	     if (ctrl_counter_input == `INSTR_HIT)
	       begin
		  instr_hit_cnt <= instr_hit_cnt + 1;
		  cache_hit_cnt <= cache_hit_cnt + 1;
	       end
	     else if (ctrl_counter_input == `INSTR_MISS)
	       begin
		  instr_miss_cnt <= instr_miss_cnt + 1;
		  cache_miss_cnt <= cache_miss_cnt + 1;
	       end 
	     else if (ctrl_counter_input == `DATA_READ_HIT)
	       begin
		  data_read_hit_cnt <= data_read_hit_cnt + 1;
		  data_hit_cnt <= data_hit_cnt + 1;
		  cache_hit_cnt <= cache_hit_cnt + 1;	  
	       end
	     else if (ctrl_counter_input == `DATA_WRITE_HIT)
	       begin
		  data_write_hit_cnt <= data_write_hit_cnt + 1;
		  data_hit_cnt <= data_hit_cnt + 1;
		  cache_hit_cnt <= cache_hit_cnt + 1;
	       end
	     else if (ctrl_counter_input == `DATA_READ_MISS)
	       begin
		  data_read_miss_cnt <= data_read_miss_cnt + 1;
		  data_miss_cnt <= data_miss_cnt + 1;
		  cache_miss_cnt <= cache_miss_cnt + 1;
	       end
	     else if (ctrl_counter_input == `DATA_WRITE_MISS)
	       begin
		  data_write_miss_cnt <= data_write_miss_cnt + 1;
		  data_miss_cnt <= data_miss_cnt + 1;
		  cache_miss_cnt <= cache_miss_cnt + 1;
	       end
	     else
	       begin
		  instr_hit_cnt <= instr_hit_cnt;
		  instr_miss_cnt <= instr_miss_cnt;
		  data_read_hit_cnt <= data_read_hit_cnt;
		  data_read_miss_cnt <= data_read_miss_cnt;
		  data_write_hit_cnt <= data_write_hit_cnt;
		  data_write_miss_cnt <= data_write_miss_cnt;
		  data_hit_cnt <= data_hit_cnt;
		  data_miss_cnt <= data_miss_cnt;
		  cache_hit_cnt <= cache_hit_cnt;
		  cache_miss_cnt <= cache_miss_cnt;
	       end
	  end
     end

`ifdef CTRL_CLK   
   always @(posedge clk, posedge ctrl_arst)
     begin
	if (ctrl_arst)
	  ctrl_clk_cnt <= {(2*DATA_W){1'b0}};
	else 
	  begin
	     if (ctrl_clk_start)
	       ctrl_clk_cnt <= ctrl_clk_cnt +1;
	     else
	       ctrl_clk_cnt <= ctrl_clk_cnt;
	  end
     end
`endif
   
   always @ (posedge clk)
     begin
	ctrl_req_data <= {DATA_W{1'b0}};
	ctrl_cache_invalid <= 1'b0;
	ctrl_counter_reset <= 1'b0;
	ctrl_ack <= ctrl_cpu_req; // Sends acknowlege the next clock cycle after request (handshake)
	
`ifdef CTRL_CLK
	ctrl_clk_start <= ctrl_clk_start;
`endif	
	if(ctrl_cpu_req)
	  begin
	     if (ctrl_addr == `ADDR_CACHE_HIT)
	       ctrl_req_data <= cache_hit_cnt;
	     else if (ctrl_addr == `ADDR_CACHE_MISS)
	       ctrl_req_data <= cache_miss_cnt;
	     else if (ctrl_addr == `ADDR_INSTR_HIT)
	       ctrl_req_data <= instr_hit_cnt;
	     else if (ctrl_addr == `ADDR_INSTR_MISS)
	       ctrl_req_data <= instr_miss_cnt;
	     else if (ctrl_addr == `ADDR_DATA_HIT)
	       ctrl_req_data <= data_hit_cnt;
	     else if (ctrl_addr == `ADDR_DATA_MISS)
	       ctrl_req_data <= data_miss_cnt;
	     else if (ctrl_addr == `ADDR_DATA_READ_HIT)
	       ctrl_req_data <= data_read_hit_cnt;
	     else if (ctrl_addr == `ADDR_DATA_READ_MISS)
	       ctrl_req_data <= data_read_miss_cnt;
	     else if (ctrl_addr == `ADDR_DATA_WRITE_HIT)
	       ctrl_req_data <= data_write_hit_cnt;
	     else if (ctrl_addr == `ADDR_DATA_WRITE_MISS)
	       ctrl_req_data <= data_write_miss_cnt;
	     else if (ctrl_addr == `ADDR_RESET_COUNTER)
	       ctrl_counter_reset <= 1'b1;
	     else if (ctrl_addr == `ADDR_CACHE_INVALIDATE)
	       ctrl_cache_invalid <= 1'b1;	
	     else if (ctrl_addr == `ADDR_BUFFER_EMPTY)
               ctrl_req_data <= ctrl_buffer_state[0];
             else if (ctrl_addr == `ADDR_BUFFER_FULL)
               ctrl_req_data <= ctrl_buffer_state[1];              
`ifdef CTRL_CLK
	     else if (ctrl_addr == `ADDR_CLK_START)
	       begin
		  ctrl_counter_reset <= 1'b1;
		  ctrl_clk_start <= 1'b1;
	       end
	     else if (ctrl_addr == `ADDR_CLK_STOP)
	       ctrl_clk_start <= 1'b0;
	     else if (ctrl_addr == `ADDR_CLK_UPPER)
	       ctrl_req_data <= ctrl_clk_cnt [2*DATA_W-1:DATA_W];
	     else if (ctrl_addr == `ADDR_CLK_LOWER)
	       ctrl_req_data <= ctrl_clk_cnt [DATA_W-1:0];
`endif
	  end
     end		    
endmodule // cache_debugger  


// One-hot to binary encoder (if input is (0)0 or (0)1, the output is 0)
module onehot_to_bin #(
		       parameter BIN_W = 2
		       )
   (
    input [2**BIN_W-1:1]   onehot ,
    output reg [BIN_W-1:0] bin 
    );
   always @ (onehot) begin: onehot_to_binary_encoder
      integer i;
      reg [BIN_W-1:1] bin_cnt ;
      bin_cnt = 0;
      for (i=1; i<2**BIN_W; i=i+1)
        if (onehot[i]) bin_cnt = bin_cnt|i;
      bin = bin_cnt;    
   end
endmodule  // onehot_to_bin


module replacement_policy_algorithm #(
				      parameter NWAY_W = 2,
				      parameter NLINE_W = 2
				      )
   (
    input [2**NWAY_W-1:0] cache_hit,
    input [NLINE_W-1:0]   index,
    input                 clk,
    input                 reset,
    input                 write_en,
    output [NWAY_W-1:0]   nway_sel 
    );

   parameter NWAYS = 2**NWAY_W; //number of ways: to simplify in reading the following algorithms
   
   
`ifdef BIT_PLRU
   wire [NWAYS -1:0]      mru_output;
   wire [NWAYS -1:0]      mru_input = (&(mru_output | cache_hit))? {NWAYS{1'b0}} : mru_output | cache_hit; //When the cache access results in a hit (or access (wish would be 1 in cache_hit even during a read-miss), it will add to the MRU, if after the the OR with Cache_hit, the entire input is 1s, it resets
   wire [NWAYS -1:0]      bitplru = (~mru_output); //least recent used
   wire [0:NWAYS -1]      bitplru_liw = bitplru [NWAYS -1:0]; //LRU Lower-Index-Way priority
   wire [(NWAYS**2)-1:0]  ext_bitplru;// Extended LRU
   wire [(NWAYS**2)-(NWAYS)-1:0] cmp_bitplru;//Result for the comparision of the LRU values (lru_liw), to choose the lowest index way for replacement. All the results of the comparision will be placed in the wire. This way the comparing all the Ways will take 1 clock cycle, instead of 2**NWAY_W cycles.
   wire [NWAYS-1:0]              bitplru_sel;  

   genvar 			 i;
   generate
      for (i = 0; i < NWAYS; i=i+1)
	begin
	   assign ext_bitplru [((i+1)*NWAYS)-1 : i*NWAYS] = bitplru_liw[i] << (NWAYS-1 -i); // extended signal of the LRU, placing the lower indexes in the higher positions (higher priority)
	end

      assign cmp_bitplru [NWAYS-1:0] = (bitplru_liw[i])? ext_bitplru[2*(NWAYS)-1: NWAYS] : ext_bitplru[NWAYS -1: 0]; //1st iteration: higher index in lru_liw is the lower indexes in LRU, if the lower index is bit-PLRU, it's stored their extended value
      
      for (i = 2; i < NWAYS; i=i+1)
	begin
	   assign cmp_bitplru [((i)*NWAYS)-1 : (i-1)*NWAYS] = (bitplru_liw[i])? ext_bitplru [((i+1)*NWAYS)-1 : i*NWAYS] : cmp_bitplru [((i-1)*NWAYS)-1 : (i-2)*NWAYS]; //if the Lower index of LRU is valid for replacement (LRU), it's placed, otherwise keeps the previous value
	end
   endgenerate
   assign bitplru_sel = cmp_bitplru [(NWAYS**2)-(NWAYS)-1 :(NWAYS**2)-2*(NWAYS)]; //the way to be replaced is the last word in cmp_lru, after all the comparisions, having there the lowest index way LRU 



`elsif LRU

   wire [NWAYS*NWAY_W -1:0] mru_output, mru_input;
   wire [NWAYS*NWAY_W -1:0] mru_check; //For checking the MRU line, to initialize it if it wasn't
   wire [NWAYS*NWAY_W -1:0] mru_cnt; //updates the MRU line, the way used will be the highest value, while the others are decremented
   wire [NWAYS -1:0]        mru_cnt_way_en; //Checks if decrementation should be done, if there isn't any way that received an hit while already being highest priority
   wire 		    mru_cnt_en = &mru_cnt_way_en; //checks if the hit was in a way that wasn't the highest priority
   wire [NWAY_W -1:0]       mru_hit_min [NWAYS :0];
   wire [NWAYS -1:0]        lru_sel; //selects the way to be replaced, using the LSB of each Way's section
   assign mru_hit_min [0] [NWAY_W -1:0] = {NWAY_W{1'b0}};
   genvar 		    i;
   generate
      for (i = 0; i < NWAYS; i=i+1)
	begin
	   assign mru_check [(i+1)*NWAY_W -1: i*NWAY_W] = (|mru_output)? mru_output [(i+1)*NWAY_W -1: i*NWAY_W] : i; //verifies if the mru line has been initialized (if any bit in mru_output is HIGH), otherwise applies the priority values, where the lower way indexes are the least recent (lesser priority)
	   assign mru_cnt_way_en [i] = ~(&(mru_check [NWAY_W*(i+1) -1 : i*NWAY_W]) && cache_hit[i]) && (|cache_hit); //verifies if there is an hit, and if the hit is the MRU way ({NWAY_{1'b1}} => & MRU = 1,) (to avoid updating during write-misses)
	   
	   assign mru_hit_min [i+1][NWAY_W -1:0] = mru_hit_min[i][NWAY_W-1:0] | ({NWAY_W{cache_hit[i]}} & mru_check [(i+1)*NWAY_W -1: i*NWAY_W]); //in case of a write hit, get's the minimum value that can be decreased in mru_cnt, to avoid (subtracting) overflows
	   
	   assign mru_cnt [(i+1)*NWAY_W -1: i*NWAY_W] = (cache_hit[i])? (NWAYS-1) : ((mru_check[(i+1)*NWAY_W -1: i*NWAY_W] > mru_hit_min[NWAYS][NWAY_W -1:0])? (mru_check [(i+1)*NWAY_W -1: i*NWAY_W] - 1) : mru_check [(i+1)*NWAY_W -1: i*NWAY_W]); //if the way was used, put it's in the highest value, otherwise reduces if the value of the position is higher than the previous value that was hit
	   
	   assign lru_sel [i] =&(~mru_check[(i+1)*NWAY_W -1: i*NWAY_W]); // The way is selected if it's value is 0s; the check is used since itś either the output, or, it this is unintialized, places the LRU as the lowest index (otherwise the first would would be the highest.
	end
   endgenerate
   assign mru_input = (mru_cnt_en)? mru_cnt : mru_output; //If an hit occured, and the way hitted wasn't the MRU, then it updates.
   

   
`elsif TREE_PLRU
   
   wire [NWAYS -1: 1] t_plru, t_plru_output;
   wire [NWAYS -1: 0] nway_tree [NWAY_W: 0]; // the order of the way index will be [lower; ...; higher way index], for readable reasons
   wire [NWAYS -1: 0] tplru_sel;
   genvar 	      i, j, k;

   // Tree-structure: t_plru[i] = tree's bit i (0 - top, towards bottom of the tree)
   generate      
      for (i = 1; i <= NWAY_W; i = i + 1)
	begin
	   for (j = 0; j < (1<<(i-1)) ; j = j + 1)
	     begin
		assign t_plru [(1<<(i-1))+j] = (t_plru_output[(1<<(i-1))+j] || (|cache_hit[NWAYS-(2*j*(NWAYS>>i)) -1: NWAYS-(2*j+1)*(NWAYS>>i)])) && (~(|cache_hit[(NWAYS-(2*j+1)*(NWAYS>>i)) -1: NWAYS-(2*j+2)*(NWAYS>>i)])); // (t-bit + |cache_hit[top_section]) * (~|cache_hit[lower_section])
	     end
	end
   endgenerate
   
   // Tree's Encoder (to translate it into selectable way) -- nway_tree will represent the indexes of the way to be selected, but it's order is inverted to be more readable (check treeplru_sel)
   assign nway_tree [0] = {NWAYS{1'b1}}; // the first position of the tree's matrix will be all 1s, for the AND logic of the following algorithm work properlly
   generate
      for (i = 1; i <= NWAY_W; i = i + 1)
	begin
	   for (j = 0; j < (1 << (i-1)); j = j + 1)
	     begin
		for (k = 0; k < (NWAYS >> i); k = k + 1)
		  begin
		     assign nway_tree [i][j*(NWAYS >> (i-1)) + k] = nway_tree [i-1][j*(NWAYS >> (i-1)) + k] && ~(t_plru [(1 << (i-1)) + j]); // the first half will be the Tree's bit inverted (0 equal Left (upper position)
		     assign nway_tree [i][j*(NWAYS >> (i-1)) + k + (NWAYS >> i)] = nway_tree [i-1][j*(NWAYS >> (i-1)) + k] && t_plru [(1 << (i-1)) + j]; //second half of the same Tree's bit (1 equals Right (lower position))
		  end	
	     end
	end 
      // placing the way select wire in the correct order for the onehot-binary encoder
      for (i = 0; i < NWAYS; i = i + 1)
	begin
	   assign tplru_sel[i] = nway_tree [NWAY_W][NWAYS - i -1];//the last row of nway_tree has the result of the Tree's encoder
	end 				
   endgenerate
   
   
`endif				      
   

   //Selects the least recent used way (encoder for one-hot to binary format)
   onehot_to_bin #(
		   .BIN_W (NWAY_W)	       
		   ) 
   lru_selector
     (
`ifdef BIT_PLRU       
      .onehot(bitplru_sel[NWAYS-1:1]),
`elsif LRU     
      .onehot(lru_sel[NWAYS-1:1]),
`elsif TREE_PLRU
      .onehot(tplru_sel[NWAYS-1:1]),
`endif
      .bin(nway_sel)
      );

   
   //Most Recently Used (MRU) memory	   
   generable_memory  #(
		       .ADDR_W (NLINE_W),
`ifdef BIT_PLRU
		       .DATA_W (NWAYS),
		       .MEM_W  (NWAYS),
`elsif LRU 		
		       .DATA_W (NWAYS*NWAY_W),
		       .MEM_W  (NWAYS*NWAY_W),
`elsif TREE_PLRU
		       .DATA_W (NWAYS-1),
		       .MEM_W  (NWAYS-1),
`endif
                       .N_MEM (1)
		       ) 
   mru_memory //simply uses the same format as valid memory
     (
      .clk         (clk          ),
      .rst         (reset        ),
`ifdef TREE_PLRU
      .mem_write_data(t_plru       ),
      .mem_read_data (t_plru_output),
`else
      .mem_write_data(mru_input    ),
      .mem_read_data (mru_output   ),			        

`endif      
      .mem_addr      (index        ),
      .mem_en        (write_en     )
      );
   
endmodule



module write_through_ctrl
  #(
    parameter ADDR_W   = 32,
    parameter DATA_W   = 32,
    parameter N_BYTES  = DATA_W/8,
    parameter WTBUF_DEPTH_W = 4
    ) 
   (
    input                    clk,
    input                    reset,
    input                    cpu_req,
    input [ADDR_W-1:2]       cache_addr,
    input [N_BYTES-1:0]      cache_wstrb,
    input [DATA_W-1:0]       cache_wdata,
    // Buffer status
    output                   buffer_empty,
    output                   buffer_full,
    // AXI interface 
    // Address Write
    output [0:0]             AW_ID, 
    output reg [ADDR_W-1:0]  AW_ADDR,
    output [7:0]             AW_LEN,
    output [2:0]             AW_SIZE,
    output [1:0]             AW_BURST,
    output [0:0]             AW_LOCK,
    output [3:0]             AW_CACHE,
    output [2:0]             AW_PROT,
    output [3:0]             AW_QOS,
    output reg               AW_VALID,
    input                    AW_READY,
    //Write                  
    output reg [DATA_W-1:0]  W_DATA,
    output reg [N_BYTES-1:0] W_STRB,
    output reg               W_LAST,
    output reg               W_VALID, 
    input                    W_READY,
    input [0:0]              B_ID,
    input [1:0]              B_RESP,
    input                    B_VALID,
    output reg               B_READY
    );


   wire [(N_BYTES) + (ADDR_W - 2) + (DATA_W) -1 :0] buffer_data_out, buffer_data_in; // {wstrb, addr [ADDR_W-1:2], word}
   

   assign buffer_data_in = {cache_wstrb, cache_addr, cache_wdata};
   
   
   //Constant AXI signals
   assign AW_ID = 1'd0;
   assign AW_LEN = 8'd0;
   assign AW_SIZE = 3'b010;
   assign AW_BURST = 2'd0;
   assign AW_LOCK = 1'b0; // 00 - Normal Access
   assign AW_CACHE = 4'b0011;
   assign AW_PROT = 3'd0;
   assign AW_QOS = 4'd0;

   

   //// buffer FSM states and register ////
   parameter
     buffer_stand_by           = 2'd0,
     buffer_write_validation   = 2'd1,
     buffer_write_to_mem       = 2'd2,
     buffer_write_verification = 2'd3;  
   
   reg [1:0]                                        buffer_state;

   always @ (posedge clk, posedge reset)
     begin
	AW_ADDR  <= {(ADDR_W){1'b0}};
	AW_VALID <= 1'b0;
	W_VALID  <= 1'b0;
	W_STRB   <= {N_BYTES{1'b0}};
	B_READY  <= 1'b1;
	W_DATA   <= {DATA_W{1'b0}};
	W_LAST   <= 1'b0;
	
	if (reset) buffer_state <= buffer_stand_by;
	else
	  case (buffer_state)
	    
	    buffer_stand_by:
	      begin
		 if (buffer_empty) buffer_state <= buffer_stand_by; 
		 else              buffer_state <= buffer_write_validation;
	      end 

	    buffer_write_validation:
	      begin
		 AW_ADDR  <= {buffer_data_out [(ADDR_W - 2 + DATA_W) - 1 : DATA_W], 2'b00};
		 AW_VALID <= 1'b1;
		 if (AW_READY) buffer_state <= buffer_write_to_mem; 
		 else          buffer_state <= buffer_write_validation;
	      end        
	    
	    buffer_write_to_mem:
	      begin        //buffer_data_out = {wstrb, address, word_size (DATA_W)}  
		 W_VALID  <=  1'b1;
		 W_STRB   <=  buffer_data_out [(N_BYTES + ADDR_W -2 + DATA_W) -1 : ADDR_W -2 + DATA_W];
		 W_LAST   <=  1'b1;
		 W_DATA   <=  buffer_data_out [DATA_W -1 : 0];
		 if (W_READY) buffer_state <= buffer_write_verification;             
		 else         buffer_state <= buffer_write_to_mem;
	      end

	    buffer_write_verification:
	      begin
		 B_READY <= 1'b1;
		 if (B_VALID)
		   if (~B_RESP[1]) //00 or 01 for OKAY response
		     buffer_state <= buffer_stand_by;
		   else
		     buffer_state <= buffer_write_validation; //re-writes, the previous write was unsuccessfull
		 else
		   buffer_state <= buffer_write_verification;
	      end
	    
	    default:        
	      begin
		 buffer_state <= buffer_stand_by;
	      end
	    
	  endcase    
     end         

   
   wire                                             buffer_read_en = (~buffer_empty) && (buffer_state == buffer_stand_by);
   

   iob_async_fifo #(
		    .DATA_WIDTH (N_BYTES+ADDR_W-2+DATA_W),
		    .ADDRESS_WIDTH (WTBUF_DEPTH_W)
		    ) 
   buffer 
     (
      .rst     (reset                    ),
      .data_out(buffer_data_out          ), 
      .empty   (buffer_empty             ),
      .level_r (),
      .read_en (buffer_read_en           ),
      .rclk    (clk                      ),    
      .data_in (buffer_data_in           ), 
      .full    (buffer_full              ),
      .level_w (),
      .write_en((|cache_wstrb) && cpu_req),
      .wclk    (clk                      )
      );

endmodule



module line_loader_ctrl 
  #(
`ifdef L1
    parameter I_OFFSET_W = 2,
`endif
`ifdef ASSOC_CACHE
    parameter NWAY_W = 4,
`endif
    parameter ADDR_W   = 32,
    parameter DATA_W   = 32,
    parameter N_BYTES  = DATA_W/8,
    parameter OFFSET_W = 2
    )
   (
    input                           clk,
    input                           reset,
`ifdef L1
    input                           instr_req,
`endif
    input [ADDR_W -1: 2 + OFFSET_W] cache_addr,
    input                           read_verification, //Read verification FSM state (state == read_verification)
    input                           cache_miss, //~(|cache_hit)
    input                           buffer_empty,
    output reg                      data_load,
    output reg [OFFSET_W-1:0]       select_counter, 
    // AXI interface  
    //Address Read
    output [0:0]                    AR_ID,
    output reg [ADDR_W-1:0]         AR_ADDR, 
    output reg [7:0]                AR_LEN,
    output reg [2:0]                AR_SIZE,
    output reg [1:0]                AR_BURST,
    output [0:0]                    AR_LOCK,
    output [3:0]                    AR_CACHE,
    output [2:0]                    AR_PROT,
    output [3:0]                    AR_QOS,
    output reg                      AR_VALID, 
    input                           AR_READY,
    //Read
    input [0:0]                     R_ID,
    //input [DATA_W-1:0]        R_DATA, //this module only controls the Data loading, doesn't receive it
    input [1:0]                     R_RESP,
    input                           R_LAST, 
    input                           R_VALID, 
    output reg                      R_READY 
    );

   //Constant AXI signals
   assign AR_ID = 1'd0;
   assign AR_LOCK = 1'b0;
   assign AR_CACHE = 4'b0011;
   assign AR_PROT = 3'd0;
   assign AR_QOS = 4'd0;
   
   //// read fail Auxiliary FSM states and register //// -> Loading Data (to Data line/Block)
   parameter
     read_stand_by     = 2'd0,
     data_loader_init  = 2'd1,
     data_loader       = 2'd2,
     data_loader_dummy = 2'd3;
   
   
   reg [1:0]                        read_state;

   always @ (posedge clk, posedge reset)
     begin
	
	AR_ADDR  <= {ADDR_W{1'b0}};
	AR_VALID <= 1'b0;
	AR_LEN   <= 8'd0;
	AR_SIZE  <= 3'b000;
	AR_BURST <= 2'b00;
	R_READY  <= 1'b0;
        select_counter <= {OFFSET_W{1'b0}};
	if (reset)
          begin
	     read_state <= read_stand_by; //reset
	     data_load <= 1'b0;
	  end	  
	else
	   
	  case (read_state)
	    
	    read_stand_by://0
	      begin
                 if ((read_verification) &&  (cache_miss && buffer_empty))
		   begin
		      read_state <= data_loader_init; //read miss
		      data_load <= 1'b1;	  
		   end
		 else 
		   begin
		      read_state <= read_stand_by; //idle
		      data_load <= 1'b0;
		   end
	      end 
	    
	    
	    data_loader_init://1
	       
	      begin
		 AR_VALID <= 1'b1;
`ifdef L1
                 AR_ADDR  <= (instr_req)? {cache_addr[ADDR_W -1 : I_OFFSET_W + 2], {(I_OFFSET_W+2){1'b0}}} : {cache_addr[ADDR_W -1 : OFFSET_W + 2], {(OFFSET_W+2){1'b0}}}; //addr = {tag,index,0...00,00} => word_select = 0...00
                 AR_LEN  <= (instr_req)? 2**(I_OFFSET_W)-1 :  2**(OFFSET_W)-1;
`else        
                 AR_ADDR  <= {cache_addr[ADDR_W -1 : OFFSET_W + 2], {(OFFSET_W+2){1'b0}}}; //addr = {tag,index,0...00,00} => word_select = 0...00
                 AR_LEN   <= 2**(OFFSET_W)-1;
`endif
		 AR_SIZE <= $clog2(N_BYTES); // VERIFY BETTER OPTION FOR PARAMETRIZATION
		 AR_BURST <= 2'b01; //INCR
		 data_load <= 1'b1;
		 
		 if (AR_READY) read_state  <= data_loader;
		 else          read_state  <= data_loader_init;
	      end 
	    
	    
	    data_loader://2
	      begin
	         if (R_VALID)
		   begin
		      if (R_LAST)
	                begin
			   R_READY <= 1'b0;
			   read_state <= read_stand_by;
			   data_load <= 1'b0;
			   select_counter <= select_counter;
	                end else begin
			   R_READY <= 1'b1;
			   select_counter <= select_counter + 1;                    
			   read_state <= data_loader;
                        end
		      
		   end else begin 
		      R_READY <= 1'b1;   
		      select_counter <= select_counter;
		      read_state <= data_loader;  
		   end
	      end  
	    
	    default:        
	      begin
		 read_state <= read_stand_by;
	      end
            
	  endcase    
     end                        

endmodule




module memory_cache 
  #(
    parameter ADDR_W   = 32,
    parameter DATA_W   = 32,
    parameter N_BYTES  = DATA_W/8,
    parameter NLINE_W  = 4,
    parameter OFFSET_W = 2,
`ifdef L1
    parameter I_NLINE_W = 3,
    parameter I_OFFSET_W = 2,
`endif
`ifdef ASSOC_CACHE
    parameter NWAY_W   = 2,
`endif
    parameter WTBUF_DEPTH_W = 4
    )
   (
    // iob_cache port signals
    input                    clk,
    input                    reset,
    input [DATA_W-1:0]       cache_write_data,
    input [N_BYTES-1:0]      cache_wstrb,
    input [ADDR_W-1:2]       cache_addr,
    output reg [DATA_W-1:0]  cache_read_data,
    input                    cpu_req,
    // input signals
    input                    cache_read_miss, // verification state == read_miss  
    input                    data_load,
    input [OFFSET_W-1 :0]    select_counter,
    input                    buffer_empty,
    input                    buffer_full,
    input                    cache_invalidate,
    input                    write_enable,
`ifdef L1 
    input                    instr_req,// cache_ctrl_instr_access
`endif 
`ifdef ASSOC_CACHE
    output [2**NWAY_W -1: 0] cache_hit_output,
`else
    output                   cache_hit_output,
`endif
    //AXI - input Read signals
    input [DATA_W-1:0]       R_DATA,
    input                    R_READY
    );
   
   parameter TAG_W = ADDR_W - (NLINE_W + 2 + OFFSET_W);
   
   //wire 		    data_load;
   //wire [OFFSET_W-1 :0]     select_counter;
   wire [OFFSET_W-1:0]       offset = cache_addr [(OFFSET_W + 1):2];//last 2 bits are 0
   wire [NLINE_W-1:0]        index = cache_addr [NLINE_W + OFFSET_W + 1 : OFFSET_W + 2];
   wire [OFFSET_W - 1:0]     word_select= (data_load)? select_counter : offset;
   wire [DATA_W -1 : 0]      write_data = (data_load)? R_DATA : cache_write_data; //when a read-fail, the data is read from the main memory, otherwise is the input write data 
   //wire 		    buffer_full, buffer_empty;
   // wire 		    cache_invalidate;
   //reg 			     write_enable; //Enables the write in memories like Data (still depends on the wstrb) and algorithm's (it goes high at the end of the task, after all procedures have concluded)


`ifdef ASSOC_CACHE
   wire [(2**NWAY_W)*DATA_W*(2**OFFSET_W) - 1: 0] data_read;
   wire [2**NWAY_W -1: 0]                         cache_hit;//uses one-hot numenclature
   wire [NWAY_W -1: 0]                            nway_hit; // Indicates the way that had a cache_hit
   wire [NWAY_W -1: 0]                            nway_sel;
 `ifdef L1
   parameter I_TAG_W = ADDR_W - (I_NLINE_W + I_OFFSET_W + 2); //Instruction TAG Width: last 2 bits are always 00 (4 Bytes = 32 bits)
   //wire 					  instr_req = cache_ctrl_instr_access;
   wire [2**NWAY_W -1: 0]                         instr_cache_hit, data_cache_hit;//uses one-hot numenclature
   wire [NWAY_W -1: 0]                            instr_nway_sel, data_nway_sel;
   wire [(2**NWAY_W)*DATA_W*(2**I_OFFSET_W) - 1: 0] instr_read;
   wire [(2**NWAY_W)-1:0]                           instr_v, data_v;
   wire [(2**NWAY_W)*I_TAG_W-1:0]                   instr_tag;
   wire [(2**NWAY_W)*TAG_W-1:0]                     data_tag;
   wire [(2**NWAY_W)-1 : 0]                         instr_tag_val, data_tag_val; //TAG Validation
   wire [NLINE_W-1:0]                               instr_index = cache_addr[NLINE_W + I_OFFSET_W + 1 : I_OFFSET_W + 2];
   wire [NLINE_W-1:0]                               data_index = cache_addr[NLINE_W + OFFSET_W + 1 : OFFSET_W + 2];
   wire [I_OFFSET_W-1:0]                            instr_offset = cache_addr [(I_OFFSET_W + 1):2];//last 2 bits are 0
   wire [I_OFFSET_W - 1:0]                          instr_word_select= (data_load)? select_counter [I_OFFSET_W-1:0] : instr_offset;
 `else
   wire [(2**NWAY_W)-1 : 0]                         tag_val; //TAG Validation
   wire [(2**NWAY_W)-1:0]                           v;
   wire [(2**NWAY_W)*TAG_W-1:0]                     tag;
 `endif
`else 
   wire [DATA_W*(2**OFFSET_W) - 1: 0]               data_read;
   wire 					    cache_hit;
 `ifdef L1
   parameter I_TAG_W = ADDR_W - (I_NLINE_W + I_OFFSET_W + 2); //Instruction TAG Width: last 2 bits are always 00 (4 Bytes = 32 bits)
   wire 					    data_v, instr_v;
   wire [TAG_W-1:0]                                 data_tag;
   wire [I_TAG_W -1:0]                              instr_tag;
   wire [DATA_W*(2**I_OFFSET_W) - 1: 0]             instr_read;
   wire [I_OFFSET_W-1:0]                            instr_offset = cache_addr [(I_OFFSET_W + 1):2];//last 2 bits are 0
   wire [I_NLINE_W-1:0]                             instr_index = cache_addr [I_NLINE_W + I_OFFSET_W + 1 : I_OFFSET_W + 2];
   wire [I_OFFSET_W - 1:0]                          instr_word_select= (data_load)? select_counter [I_OFFSET_W-1:0] : instr_offset;
 `else // !`ifdef L1
   wire 					    v;
   wire [TAG_W-1:0]                                 tag;
 `endif // !`ifdef L1 
`endif // !`ifdef ASSOC_CACHE
   
   assign cache_hit_output = cache_hit;
   

   
   
`ifdef L1
   
 `ifdef ASSOC_CACHE // ASSOCIATIVE CACHE L1 (INSTR CACHE + DATA CACHE)

   assign nway_sel = (instr_req)? instr_nway_sel : data_nway_sel;
   
   reg [NWAY_W-1:0]                                 nway_selector;
   always @ (posedge clk)
     begin
        nway_selector <= nway_hit; // nway_hit start at 1 (hit at position 0)
        if  (cache_read_miss)
          nway_selector <= nway_sel;
     end  


   wire [N_BYTES-1:0] 					  data_line_wstrb;           
   assign data_line_wstrb = (write_enable)? (cache_wstrb & {N_BYTES{cpu_req}}) :  {N_BYTES{R_READY}}; 
   genvar 						  i, j;
   
   generate
      for (j = 0; j < 2**NWAY_W; j=j+1)
	begin
	   //DATA CACHE
	   for (i = 0; i < 2**OFFSET_W; i=i+1)
	     begin
                generable_memory #(
                                   .RESET (0),
			           .ADDR_W (NLINE_W),
                                   .MEM_W (8),
                                   .N_MEM (N_BYTES)
			           ) 
		data_memory 
		    (
		     .clk           (clk                                                                    ),
                     .rst           (1'b0),
		     .mem_write_data(write_data                                                             ),
		     .mem_addr      (index                                                                  ),
		     .mem_en        (((i == word_select) && (j == nway_selector) && (data_load || cache_hit[j]) && (!instr_req))? data_line_wstrb : {N_BYTES{1'b0}}),
		     .mem_read_data (data_read [(j*(2**OFFSET_W)+(i+1))*DATA_W-1:(j*(2**OFFSET_W)+i)*DATA_W]) 
		     ); 
		
	     end 
	   
           generable_memory #(
                              .RESET (0),
			      .ADDR_W (NLINE_W), 
			      .DATA_W (TAG_W),
                              .MEM_W (TAG_W),
                              .N_MEM (1)
			      ) 
	   data_mem_tag 
	     (
	      .clk           (clk                                         ),
              .rst           (1'b0),
	      .mem_write_data(cache_addr[ADDR_W-1:(ADDR_W-TAG_W)]         ),
	      .mem_addr      (index                                       ),
	      .mem_en        ((j == nway_sel)? data_load&(!instr_req):1'b0),
	      .mem_read_data (data_tag[TAG_W*(j+1)-1 : TAG_W*j]           )                                             
	      );

	   assign data_tag_val[j] = (cache_addr[ADDR_W-1:(ADDR_W-TAG_W)] == data_tag[TAG_W*(j+1)-1 : TAG_W*j]);
	   

           generable_memory #(
                              .RESET (1),
			      .ADDR_W (NLINE_W), 
			      .DATA_W (1),
                              .MEM_W (1),
                              .N_MEM (1)
			      ) 
	   data_valid 
	     (
	      .clk         (clk                                           ),
	      .rst       (reset || cache_invalidate                     ),
	      .mem_write_data(data_load                                     ),		           
	      .mem_addr      (index                                         ),
	      .mem_en        ((j == nway_sel)? data_load & (!instr_req):1'b0),
	      .mem_read_data (data_v[j]                        )   
	      );


	   //INSTRUCTION CACHE
	   for (i = 0; i < 2**I_OFFSET_W; i=i+1)
	     begin
                generable_memory #(
                                   .RESET (0),
			           .ADDR_W (I_NLINE_W),
                                   .DATA_W (DATA_W),
                                   .MEM_W (8),
                                   .N_MEM (N_BYTES)
			           ) 
	        instr_memory 
		    (
		     .clk           (clk                                                                    ),
		     .rst           (1'b0),
                     .mem_write_data(write_data                                                             ),
		     .mem_addr      (instr_index                                                                  ),
		     .mem_en        (((i == instr_word_select) && (j == nway_selector) && (data_load) & instr_req)? {N_BYTES{R_READY}} : {N_BYTES{1'b0}} ),
		     .mem_read_data (instr_read [(j*(2**I_OFFSET_W)+(i+1))*DATA_W-1:(j*(2**I_OFFSET_W)+i)*DATA_W]) 
		     ); 
		
	     end 
	   
           generable_memory #(
                              .RESET (0),
			      .ADDR_W (I_NLINE_W), 
			      .DATA_W (I_TAG_W),
                              .MEM_W (I_TAG_W),
                              .N_MEM (1)
			      ) 
	   instr_mem_tag 
	     (
	      .clk           (clk                                          ),
	      .rst           (1'b0),
              .mem_write_data(cache_addr[ADDR_W-1:(ADDR_W-I_TAG_W)]        ),
	      .mem_addr      (instr_index                                  ),
	      .mem_en        ((j == nway_sel)? (data_load & instr_req):1'b0),
	      .mem_read_data (instr_tag[I_TAG_W*(j+1)-1 : I_TAG_W*j]       )                                             
	      );

	   assign instr_tag_val[j] = (cache_addr[ADDR_W-1:(ADDR_W-I_TAG_W)] == instr_tag[I_TAG_W*(j+1)-1 : I_TAG_W*j]);
	   

           generable_memory #(
                              .RESET (1),
			      .ADDR_W (I_NLINE_W), 
			      .DATA_W (1),
                              .MEM_W (1),
                              .N_MEM (1)
			      ) 
	   instr_valid
	     (
	      .clk         (clk                                          ),
	      .rst       (reset || cache_invalidate                    ),
	      .mem_write_data(data_load                                    ),		        
	      .mem_addr      (index                                        ),
	      .mem_en        ((j == nway_sel)? (data_load & instr_req):1'b0),
	      .mem_read_data (instr_v[j]                                   )   
	      );

	   
	   //DATA + INSTR
	   assign cache_hit[j] = (instr_req)? instr_tag_val[j] && instr_v[j] : data_tag_val[j] && data_v[j];//one-hot cache-hit	   	
	   assign instr_cache_hit[j] = instr_tag_val[j] && instr_v[j];
	   assign data_cache_hit[j] = data_tag_val[j] && data_v[j];  
	end     
   endgenerate


   onehot_to_bin #(
		   .BIN_W (NWAY_W)
		   ) 
   onehot_to_bin
     (
      .onehot(cache_hit[2**NWAY_W-1:1]),
      .bin(nway_hit)
      );
   

   
   always @ (posedge clk)
     cache_read_data [DATA_W -1:0] <= (instr_req)? instr_read >> DATA_W*(instr_word_select + (2**I_OFFSET_W)*nway_hit) : data_read >> DATA_W*(word_select + (2**OFFSET_W)*nway_hit);


   
 `else // DIRECT ACCESS L1 (INSTR CACHE + DATA CACHE)

   assign cache_hit = (instr_req)? ((instr_tag == cache_addr [ADDR_W-1 -: I_TAG_W]) && instr_v)  : ((data_tag == cache_addr [ADDR_W-1 -: TAG_W]) && data_v);
   
   wire [N_BYTES -1 :0] 	      data_line_wstrb;  
   assign data_line_wstrb = (write_enable)? (cache_wstrb & {N_BYTES{cpu_req}}) :  {N_BYTES{R_READY}}; 
   
   genvar 			      i;
   
   //DATA CACHE 
   generate  
      for (i = 0; i < 2**OFFSET_W; i=i+1)
        begin
           generable_memory #(
                              .RESET (0),
			      .ADDR_W (NLINE_W),
                              .DATA_W (DATA_W),
                              .MEM_W (8),
                              .N_MEM (N_BYTES)
			      ) 
	   data_memory 
	       (
		.clk           (clk                                 ),
                .rst           (1'b0),
		.mem_write_data(write_data                          ),
		.mem_addr      (index                               ),
		.mem_en        (((i == word_select) && (data_load || cache_hit) && (!instr_req))? data_line_wstrb : {N_BYTES{1'b0}}), 
		.mem_read_data (data_read [DATA_W*(i+1)-1: DATA_W*i])   
		);      
        end     
   endgenerate

   generable_memory #(
                      .RESET (0),
		      .ADDR_W (NLINE_W), 
		      .DATA_W (TAG_W  ),
                      .MEM_W (TAG_W),
                      .N_MEM (1)
		      ) 
   data_mem_tag 
     (
      .clk           (clk                                ),
      .rst           (1'b0),
      .mem_write_data(cache_addr[ADDR_W-1:(ADDR_W-TAG_W)]),
      .mem_addr      (index                              ),
      .mem_en        ((!instr_req) & data_load           ),
      .mem_read_data (data_tag                           )                     
      );


   generable_memory #(
                      .RESET (1),
		      .ADDR_W (NLINE_W), 
		      .DATA_W (1),
                      .MEM_W (1),
                      .N_MEM (1)
		      ) 
   data_valid 
     (
      .clk         (clk                      ),
      .rst       (reset || cache_invalidate),
      .mem_write_data(data_load                ),				        
      .mem_addr      (index                    ),
      .mem_en        ((!instr_req) & data_load ),
      .mem_read_data (data_v                   )   
      );
   
   //INSTRUCTION CACHE
   generate
      for (i = 0; i < 2**I_OFFSET_W; i=i+1)
        begin
           generable_memory #(
                              .RESET (0),
			      .ADDR_W (I_NLINE_W),
                              .DATA_W (DATA_W),
                              .MEM_W (8),
                              .N_MEM (N_BYTES)
			      ) 
	   instr_memory 
	       (
		.clk           (clk                                  ),
                .rst           (1'b0),
		.mem_write_data(write_data                           ),
		.mem_addr      (instr_index                          ),
		.mem_en        ((((i == instr_word_select) && (data_load)) && instr_req)? {N_BYTES{R_READY}} : {N_BYTES{1'b0}}), //Instruction cache only is written during cache line memory loads, during read-misses.
		.mem_read_data (instr_read [DATA_W*(i+1)-1: DATA_W*i])   
		);      
        end     
   endgenerate



   generable_memory #(
                      .RESET (0),
		      .ADDR_W (I_NLINE_W), 
		      .DATA_W (I_TAG_W  ),
                      .MEM_W (I_TAG_W),
                      .N_MEM (1)
		      ) 
   instr_mem_tag 
     (
      .clk           (clk                                  ),
      .rst           (1'b0),
      .mem_write_data(cache_addr[ADDR_W-1:(ADDR_W-I_TAG_W)]),
      .mem_addr      (instr_index                          ),
      .mem_en        (data_load & instr_req                ),
      .mem_read_data (instr_tag                            )                     
      );


   generable_memory #(
                      .RESET (1),
		      .ADDR_W (I_NLINE_W), 
		      .DATA_W (1),
                      .MEM_W (1),
                      .N_MEM (1)
		      ) 
   instr_valid 
     (
      .clk         (clk                      ),
      .rst       (reset || cache_invalidate),
      .mem_write_data(data_load                ),				        
      .mem_addr      (instr_index              ),
      .mem_en        (data_load & instr_req    ),
      .mem_read_data (instr_v                  )   
      );

   
   //Using shifts to select the correct Data memory from the cache's Data line, avoiding the use of generate. 
   always @ (posedge clk)
     cache_read_data [DATA_W -1:0] <= (instr_req)? instr_read >> (instr_word_select * DATA_W) : data_read >> (word_select * DATA_W);
   

 `endif   
   
`else // L1 CACHE (1 MEMORY)
   
 `ifdef ASSOC_CACHE //ASSOCIATIVE CACHE (1 Memory for both Data and Instructions)
   
   reg [NWAY_W-1:0]                 nway_selector;
   always @ (posedge clk)
     begin
        nway_selector <= nway_hit; // nway_hit start at 1 (hit at position 0)
        if  (cache_read_miss) //state == read_miss
          nway_selector <= nway_sel;
     end  


   wire [N_BYTES-1:0] 					  data_line_wstrb;           
   assign data_line_wstrb = (write_enable)? (cache_wstrb & {N_BYTES{cpu_req}}) :  {N_BYTES{R_READY}}; 

   genvar 						  i, j;
   generate
      for (j = 0; j < 2**NWAY_W; j=j+1)
	begin
	   for (i = 0; i < 2**OFFSET_W; i=i+1)
	     begin
	        generable_memory #(
                                   .RESET (0),
			           .ADDR_W (NLINE_W),
                                   .DATA_W (DATA_W),
                                   .MEM_W (8),
                                   .N_MEM (N_BYTES)
			           ) 
		data_memory 
		    (
		     .clk           (clk                                                                ),
		     .rst (1'b0),
		     .mem_write_data(write_data                                                         ),
		     .mem_addr      (index                                                              ),
		     .mem_en        (((i == word_select) && (j == nway_selector)) && (data_load || cache_hit[j])? data_line_wstrb : {N_BYTES{1'b0}} ),
		     .mem_read_data (data_read [(j*(2**OFFSET_W)+(i+1))*DATA_W-1:(j*(2**OFFSET_W)+i)*DATA_W]) 
		     ); 
	     end 
	   
	   generable_memory  #(
                               .RESET  (0),
			       .ADDR_W (NLINE_W), 
			       .DATA_W (TAG_W),
                               .MEM_W  (TAG_W),
                               .N_MEM  (1)
			       ) 
	   tag_memory 
	     (
	      .clk           (clk                                ), 
	      .rst (1'b0),
	      .mem_write_data(cache_addr[ADDR_W-1:(ADDR_W-TAG_W)]),
	      .mem_addr      (index                              ),
	      .mem_en        ((j == nway_sel)? data_load : 1'b0  ),
	      .mem_read_data (tag[TAG_W*(j+1)-1 : TAG_W*j]       )                                             
	      );

	   assign tag_val[j] = (cache_addr[ADDR_W-1:(ADDR_W-TAG_W)] == tag[TAG_W*(j+1)-1 : TAG_W*j]);
	   

	   generable_memory #(
                              .RESET  (1),
			      .ADDR_W (NLINE_W), 
			      .DATA_W (1),
                              .MEM_W  (1),
                              .N_MEM  (1)
			      ) 
	   valid_memory 
	     (
	      .clk         (clk                              ),
	      .rst         (reset || cache_invalidate        ),
	      .mem_write_data(data_load                        ),				       
	      .mem_addr      (index                            ),
	      .mem_en        ((j == nway_sel)? data_load : 1'b0),
	      .mem_read_data (v[j]                             )   
	      );
	   

	   assign cache_hit[j] = tag_val[j] && v[j];//one-hot cache-hit	   	
        end     
   endgenerate

   onehot_to_bin #(
		   .BIN_W (NWAY_W)
		   ) 
   onehot_to_bin
     (
      .onehot(cache_hit[2**NWAY_W-1:1]),
      .bin(nway_hit)
      );
   

   
   always @ (posedge clk)
     cache_read_data [DATA_W -1:0] <= data_read >> DATA_W*(word_select + (2**OFFSET_W)*nway_hit);

   
 `else  // DIRECT ACCESS CACHE (1 Memory for both Data and Instructions)  

   assign cache_hit = (tag == cache_addr [ADDR_W-1 -: TAG_W]) && v;
   
   wire [N_BYTES -1:0] 		      data_line_wstrb;  
   assign data_line_wstrb = (write_enable)? (cache_wstrb & {N_BYTES{cpu_req}}) :  {N_BYTES{R_READY}}; 

   genvar 			      i;
   
   generate
      for (i = 0; i < 2**OFFSET_W; i=i+1)
        begin
	   generable_memory #(
                              .RESET (0),
			      .ADDR_W (NLINE_W),
                              .DATA_W (DATA_W),
                              .MEM_W (8),
                              .N_MEM (N_BYTES)
			      ) 
	   data_memory 
	       (
		.clk           (clk                                 ),
                .rst           (1'b0),
		.mem_write_data(write_data                          ),
		.mem_addr      (index                               ),
		.mem_en        (((i == word_select) && (data_load || cache_hit))? data_line_wstrb : {N_BYTES{1'b0}}), 
		.mem_read_data (data_read [DATA_W*(i+1)-1: DATA_W*i])   
		);      
        end     
   endgenerate



   generable_memory #(
                      .RESET (0),
		      .ADDR_W (NLINE_W), 
		      .DATA_W (TAG_W),
                      .MEM_W (TAG_W),
                      .N_MEM (1)
		      ) 
   tag_memory 
     (
      .clk           (clk                                ),
      .rst           (1'b0),
      .mem_write_data(cache_addr[ADDR_W-1:(ADDR_W-TAG_W)]),
      .mem_addr      (index                              ),
      .mem_en        (data_load                          ),
      .mem_read_data (tag                                )                     
      );


   generable_memory #(
                      .RESET (1),
		      .ADDR_W (NLINE_W), 
		      .DATA_W (1),
                      .MEM_W (1),
                      .N_MEM (1)
		      ) 
   valid_memory 
     (
      .clk         (clk                      ),
      .rst       (reset || cache_invalidate),
      .mem_write_data(data_load                ),				        
      .mem_addr      (index                    ),
      .mem_en        (data_load                ),
      .mem_read_data (v                        )   
      );
   

   
   //Using shifts to select the correct Data memory from the cache's Data line, avoiding the use of generate. 
   always @ (posedge clk)
     cache_read_data [DATA_W -1:0] <= data_read >> (word_select * DATA_W);
   
 `endif // !`ifdef ASSOC_CACHE
   

`endif // !`ifdef L1

   
`ifdef ASSOC_CACHE   
 `ifdef TAG_BASED //only to be used for testing of the associative cache, not a real replacemente policy
   assign nway_sel = cache_addr [NWAY_W +1 +NLINE_W: 2+NLINE_W];
   
 `else

  `ifdef L1
   
   replacement_policy_algorithm #(
				  .NWAY_W(NWAY_W),
				  .NLINE_W(NLINE_W)
				  )
   Data_RP
     (
      .cache_hit(data_cache_hit           ),
      .index    (index                    ),
      .clk      (clk                      ),
      .reset    (reset || cache_invalidate),
      .write_en (write_enable&(!instr_req)),
      .nway_sel (data_nway_sel            )
      );
   
   replacement_policy_algorithm #(
				  .NWAY_W(NWAY_W),
				  .NLINE_W(I_NLINE_W)
				  )
   Instr_RP
     (
      .cache_hit(instr_cache_hit          ),
      .index    (instr_index              ),
      .clk      (clk                      ),
      .reset    (reset || cache_invalidate),
      .write_en (write_enable & instr_req ),
      .nway_sel (instr_nway_sel           )
      );

   
  `else
   
   replacement_policy_algorithm #(
				  .NWAY_W(NWAY_W),
				  .NLINE_W(NLINE_W)
				  )
   replacement_policy_algorithm
     (
      .cache_hit (cache_hit),
      .index (index),
      .clk (clk),
      .reset (reset || cache_invalidate),
      .write_en (write_enable),
      .nway_sel (nway_sel)
      );
   
  `endif
 `endif        
`endif //  `ifdef ASSOC_CACHE
   
endmodule



module cache_verification_controller 
  (
   input                            clk,
   input                            reset,
   input                            cpu_req,
   input                            cache_write,
   input                            cache_read,
   input                            data_load,
   input                            cache_hit,
   input                            buffer_full,
   input                            buffer_empty,
   input                            instr_access,
   output reg                       cache_ack,
   output reg                       write_enable,
   output reg [`CTRL_COUNTER_W-1:0] ctrl_counter,
   output                           cache_read_miss,
   output                           cache_read_verification
   );

   
   /// FSM states and register ////
   parameter
     stand_by              = 3'd0, 
     write_verification    = 3'd1,
     read_verification     = 3'd2,
     read_miss             = 3'd3,
     read_validation       = 3'd4,
     hit                   = 3'd5,
     end_verification      = 3'd6,
     stand_by_delay        = 3'd7;
   
   reg [2:0]                        state;
   reg [2:0]                        next_state;


   assign cache_read_miss = (state == read_miss);

   assign cache_read_verification = (state == read_verification);

   always @ (posedge clk, posedge reset)
     begin
	cache_ack <= 1'b0;
	ctrl_counter <= `CTRL_COUNTER_W'd0;
	write_enable <= 1'b0;
	
	if (reset) state <= stand_by;
	else 
	  case (state)
	    
            stand_by:
	      begin
		 if(cache_write) state <= write_verification;
		 else
		   if (cache_read) state <= read_verification;
		   else
		     state <= stand_by;
	      end

	    write_verification:
	      begin
		 if (buffer_full)
		   state <= write_verification;
		 else
		   begin
		      state <= end_verification;
		      write_enable <= 1'b1;
		      if (cache_hit)	 
			ctrl_counter <= `DATA_WRITE_HIT;
		      else
			ctrl_counter <= `DATA_WRITE_MISS;
		   end
	      end

	    
	    read_verification:
	      begin
		 if (buffer_empty) 
		   begin
		      if (cache_hit)	
			begin
			   state <= end_verification;
			   write_enable <= 1'b1;
			   if (instr_access)
			     ctrl_counter <= `INSTR_HIT;
			   else
			     ctrl_counter <= `DATA_READ_HIT;
			end
		      else 
			begin
			   state <= read_miss;	    
			   if (instr_access)
			     ctrl_counter <= `INSTR_MISS;
			   else
			     ctrl_counter <= `DATA_READ_MISS;
			end
		   end
		 else 
		   state <= read_verification; 
	      end 
	    

            read_miss:      
	      begin
		 if (data_load) //is data being loaded? wait to avoid collision
		   state <= read_miss; 
		 else
		   state <= read_validation; 
              end 

	    read_validation:
	      begin
		 state <= end_verification;
		 write_enable <= 1'b1;
	      end
	    
      	    end_verification: 
      	      begin
      	         cache_ack <= 1'b1;
      		 state <= stand_by_delay;	    
	      end
	    
            default:        
	      begin
		 state <= stand_by;
              end
	  endcase
     end                        

endmodule
