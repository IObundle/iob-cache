`timescale 1ns / 1ps
`include "iob-cache.vh"

module memory_cache #(
		      parameter ADDR_W   = 32,
		      parameter DATA_W   = 32,
		      parameter N_BYTES  = DATA_W/8,
		      parameter NLINE_W  = 3,
		      parameter OFFSET_W = 3, //log2(Line_size/DATA_W)
`ifdef L1
		      parameter I_NLINE_W = 2,
		      parameter I_OFFSET_W = 2, //Needs to be equal or less than OFFSET_W
`endif
`ifdef ASSOC_CACHE
		      parameter NWAY_W   = 1,
`endif
		      parameter BUFFER_W = 4 //Depth of the buffer that writes to the main memory (2**BUFFER_W positions)
		      ) 
   (
    input 		     clk,
    input 		     reset,
    output 		     buffer_clear,
    input [DATA_W-1:0] 	     cache_write_data,
    input [N_BYTES-1:0]      cache_wstrb,
    input [ADDR_W-1:0] 	     cache_addr,
    output reg [DATA_W-1:0]  cache_read_data,
    input 		     mem_ack,
    input 		     cpu_req,
    output reg 		     cache_ack,
    /// Cache Debugger signals
    input [`CTRL_ADDR_W-1:0] cache_ctrl_address,
    output [DATA_W-1:0]      cache_ctrl_requested_data,
    input 		     cache_ctrl_cpu_request,
    output 		     cache_ctrl_acknowledge,
    input 		     cache_ctrl_instr_access, 
    ///// AXI signals
    /// Read		    
    output reg [ADDR_W-1:0]  AR_ADDR, 
    output reg [7:0] 	     AR_LEN,
    output reg [2:0] 	     AR_SIZE,
    output reg [1:0] 	     AR_BURST,
    output reg 		     AR_VALID, 
    input 		     AR_READY,
    input 		     R_VALID, 
    output reg 		     R_READY,
    input [DATA_W-1:0] 	     R_DATA,
    input 		     R_LAST, 
    /// Write
    output reg [ADDR_W-1:0]  AW_ADDR,
    output reg 		     AW_VALID,
    input 		     AW_READY, 
    output reg 		     W_VALID,
    output reg [N_BYTES-1:0] W_STRB, 
    input 		     W_READY,
    output reg [ADDR_W-1:0]  W_DATA,
    input 		     B_VALID,
    output reg 		     B_READY 	      
    );
   
   parameter TAG_W = ADDR_W - (NLINE_W + OFFSET_W + 2); //last 2 bits are always 00 (4 Bytes = 32 bits)

`ifdef ASSOC_CACHE
   wire [(2**NWAY_W)*DATA_W*(2**OFFSET_W) - 1: 0] data_read;
   wire [(2**NWAY_W)-1:0] 			  v;
   wire [(2**NWAY_W)*TAG_W-1:0] 		  tag;
   wire [2**NWAY_W -1: 0] 			  cache_hit;//uses one-hot numenclature
   wire [NWAY_W: 0] 				  nway_hit; // Indicates the way that had a cache_hit
   wire [NWAY_W -1: 0] 				  nway_sel;
   wire [(2**NWAY_W)-1 : 0] 			  tag_val; //TAG Validation
`else 
   wire [DATA_W*(2**OFFSET_W) - 1: 0] 		  data_read;
   reg 						  data_load;
   reg [OFFSET_W-1 :0] 				  select_counter;
   wire [OFFSET_W-1:0] 				  Offset = cache_addr [(OFFSET_W + 1):2];//last 2 bits are 0
   wire [NLINE_W-1:0] 				  index = cache_addr [NLINE_W + OFFSET_W + 1 : OFFSET_W + 2];
   wire [OFFSET_W - 1:0] 			  word_select= (data_load)? select_counter : Offset;
   wire [DATA_W -1 : 0] 			  write_data = (data_load)? R_DATA : cache_write_data; //when a read-fail, the data is read from the main memory, otherwise is the input write data 
 `ifdef L1
   parameter I_TAG_W = ADDR_W - (I_NLINE_W + I_OFFSET_W + 2); //Instruction TAG Width: last 2 bits are always 00 (4 Bytes = 32 bits)
   wire 					  instr_req = cache_ctrl_instr_access;
   wire 					  data_v, instr_v;
   wire [TAG_W-1:0] 				  data_tag;
   wire [I_TAG_W -1:0] 				  instr_tag;
   wire [DATA_W*(2**I_OFFSET_W) - 1: 0] 	  instr_read;
   wire 					  cache_hit = (instr_req)? ((instr_tag == cache_addr [ADDR_W-1 -: I_TAG_W]) && instr_v)  : ((data_tag == cache_addr [ADDR_W-1 -: TAG_W]) && data_v);
   wire [I_OFFSET_W-1:0] 			  instr_Offset = cache_addr [(I_OFFSET_W + 1):2];//last 2 bits are 0
   wire [I_NLINE_W-1:0] 			  instr_index = cache_addr [I_NLINE_W + I_OFFSET_W + 1 : I_OFFSET_W + 2];
   wire [I_OFFSET_W - 1:0] 			  instr_word_select= (data_load)? select_counter [I_OFFSET_W-1:0] : instr_Offset;
 `else // !`ifdef L1
   wire 					  v;
   wire [TAG_W-1:0] 				  tag;
   wire 					  cache_hit = (tag == cache_addr [ADDR_W-1 -: TAG_W]) && v;
 `endif // !`ifdef L1 
`endif // !`ifdef ASSOC_CACHE

   wire 					  buffer_full, buffer_empty;
   wire 					  cache_invalidate;
   reg [`CTRL_COUNTER_W-1:0] 			  ctrl_counter;
   reg 						  write_enable; //Enables the write in memories like Data (still depends on the wstrb) and algorithm's (it goes high at the end of the task, after all procedures have concluded)


   //SIM signals  
   wire 					  cache_write = cpu_req & (|cache_wstrb);
   wire 					  cache_read = cpu_req & ~(|cache_wstrb);  

`ifdef ASSOC_CACHE   
 `ifdef TAG_BASED //only to be used for testing of the associative cache, not a real replacemente policy
   assign nway_sel = cache_addr [NWAY_W +1 +NLINE_W: 2+NLINE_W];
 `elsif COUNTER //only to be used for testing of the associative cache, not a real replacement policy
   reg [NWAY_W-1:0] 				  nway_sel_cnt;

   always @ (posedge cache_ack, posedge reset)
     begin
	nway_sel_cnt = nway_sel_cnt;
	if (reset)
          nway_sel_cnt = {NWAY_W{ 1'b0}};
	else if (cache_ack)
          nway_sel_cnt = nway_sel_cnt +1;
     end

   assign nway_sel = nway_sel_cnt;
   
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
   /// FSM states and register ////
   parameter
     stand_by              = 3'd0, 
     write_verification    = 3'd1,
     read_verification     = 3'd2,
     read_fail             = 3'd3,
     read_validation       = 3'd4,
     hit                   = 3'd5,
     end_verification      = 3'd6,
     stand_by_delay        = 3'd7;
   
   reg [2:0] 					  state;
   reg [2:0] 					  next_state;

   
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
		      if (|cache_hit)
			ctrl_counter <= `DATA_WRITE_HIT;
		      else
			ctrl_counter <= `DATA_WRITE_MISS;
		   end
	      end

	    
	    read_verification:
	      begin
		 if (buffer_empty) 
		   begin
		      if (|cache_hit) 
			begin
			   state <= end_verification;
			   write_enable <= 1'b1;
			   if (cache_ctrl_instr_access)
			     ctrl_counter <= `INSTR_HIT;
			   else
			     ctrl_counter <= `DATA_READ_HIT;
			end
		      else 
			begin
			   state <= read_fail;	    
			   if (cache_ctrl_instr_access)
			     ctrl_counter <= `INSTR_MISS;
			   else
			     ctrl_counter <= `DATA_READ_MISS;
			end
		   end
		 else 
		   state <= read_verification; 
	      end 
	    

            read_fail:      
	      begin
		 if (data_load) //is data being loaded? wait to avoid collision
		   state <= read_fail; 
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

   
`ifdef L1
   
 `ifdef ASSOC_CACHE // DIRECT ACCESS L1 (INSTR CACHE + DATA CACHE)
 `else 
   wire [N_BYTES -1 :0] 	      data_line_wstrb;  
   //assign data_line_wstrb = (data_load)? {N_BYTES{R_READY}} : (cache_wstrb & {N_BYTES{cpu_req}});
   assign data_line_wstrb = (write_enable)? (cache_wstrb & {N_BYTES{cpu_req}}) :  {N_BYTES{R_READY}}; 
   
   genvar 			      i;
   
   generate
      //DATA CACHE   
      for (i = 0; i < 2**OFFSET_W; i=i+1)
        begin
           data_memory #(
			 .ADDR_W (NLINE_W) 
			 ) 
	   data_memory 
	       (
		.clk           (clk       ),
		.mem_write_data(write_data),
		.mem_addr      (index     ),
		.mem_en        ((((i == word_select) && (data_load || cache_hit)) && (!instr_req))? data_line_wstrb : {N_BYTES{1'b0}}), 
		.mem_read_data (data_read [DATA_W*(i+1)-1: DATA_W*i])   
		);      
        end     
   endgenerate

   tag_memory  #(
		 .ADDR_W (NLINE_W), 
		 .DATA_W (TAG_W) 
		 ) 
   data_mem_tag 
     (
      .clk           (clk                                         ),
      .tag_write_data(cache_addr[ADDR_W-1:(ADDR_W-TAG_W)]),
      .tag_addr      (index                                       ),
      .tag_en        ((!instr_req) & data_load                        ),
      .tag_read_data (data_tag                                         )                     
      );


   valid_memory #(
		  .ADDR_W (NLINE_W), 
		  .DATA_W (1) 
		  ) 
   data_valid 
     (
      .clk         (clk       ),
      .reset       (reset   || cache_invalidate  ),
      .v_write_data(data_load ),				        
      .v_addr      (index     ),
      .v_en        ((!instr_req) & data_load ),
      .v_read_data (data_v         )   
      );
   
   //INSTRUCTION CACHE
   generate
      for (i = 0; i < 2**I_OFFSET_W; i=i+1)
        begin
           data_memory #(
			 .ADDR_W (I_NLINE_W) 
			 ) 
	   instr_memory 
	       (
		.clk           (clk       ),
		.mem_write_data(write_data),
		.mem_addr      (instr_index     ),
		.mem_en        ((((i == word_select) && (data_load || cache_hit)) && instr_req)? data_line_wstrb : {N_BYTES{1'b0}}), 
		.mem_read_data (instr_read [DATA_W*(i+1)-1: DATA_W*i])   
		);      
        end     
   endgenerate



   tag_memory  #(
		 .ADDR_W (I_NLINE_W), 
		 .DATA_W (I_TAG_W) 
		 ) 
   instr_mem_tag 
     (
      .clk           (clk                                         ),
      .tag_write_data(cache_addr[ADDR_W-1:(ADDR_W-I_TAG_W)]),
      .tag_addr      (instr_index                                       ),
      .tag_en        (data_load & instr_req                       ),
      .tag_read_data (instr_tag                                   )                     
      );


   valid_memory #(
		  .ADDR_W (I_NLINE_W), 
		  .DATA_W (1) 
		  ) 
   instr_valid 
     (
      .clk         (clk       ),
      .reset       (reset   || cache_invalidate  ),
      .v_write_data(data_load ),				        
      .v_addr      (instr_index     ),
      .v_en        (data_load & instr_req ),
      .v_read_data (instr_v   )   
      );

   
   //Using shifts to select the correct Data memory from the cache's Data line, avoiding the use of generate. 
   always @ (posedge clk)
     cache_read_data [DATA_W -1:0] <= (instr_req)? instr_read >> (instr_word_select * DATA_W) : data_read >> (word_select * DATA_W);
   

 `endif   
   
`else
   
 `ifdef ASSOC_CACHE //ASSOCIATIVE CACHE (1 Memory for both Data and Instructions)
   
   reg [NWAY_W-1:0]                 nway_selector;
   always @ (posedge clk)
     begin
        nway_selector <= nway_hit; // nway_hit start at 1 (hit at position 0)
        if  (state == read_fail)
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
		data_memory #(
			      .ADDR_W (NLINE_W) 
			      ) 
		data_memory 
		    (
		     .clk           (clk                                                                ),
		     .mem_write_data(write_data                                                         ),
		     .mem_addr      (index                                                              ),
		     .mem_en        (((i === word_select) && (j === nway_selector)) && (data_load || cache_hit[j])? data_line_wstrb : {N_BYTES{1'b0}} ),
		     .mem_read_data (data_read [(j*(2**OFFSET_W)+(i+1))*DATA_W-1:(j*(2**OFFSET_W)+i)*DATA_W]) 
		     ); 
		
		wire [2**NWAY_W -1:0] test_wire = ((i === word_select) && (j === nway_selector)) && (data_load || cache_hit[j]);
	     end 
	   
	   tag_memory  #(
			 .ADDR_W (NLINE_W), 
			 .DATA_W (TAG_W)
			 ) 
	   tag_memory 
	     (
	      .clk           (clk                                ),
	      .tag_write_data(cache_addr[ADDR_W-1:(ADDR_W-TAG_W)]),
	      .tag_addr      (index                              ),
	      .tag_en        ((j == nway_sel)? data_load : 1'b0  ),
	      .tag_read_data (tag[TAG_W*(j+1)-1 : TAG_W*j]       )                                             
	      );

	   assign tag_val[j] = (cache_addr[ADDR_W-1:(ADDR_W-TAG_W)] === tag[TAG_W*(j+1)-1 : TAG_W*j]);
	   

	   valid_memory #(
			  .ADDR_W (NLINE_W), 
			  .DATA_W (1)
			  ) 
	   valid_memory 
	     (
	      .clk         (clk                              ),
	      .reset       (reset || cache_invalidate        ),
	      .v_write_data(data_load                        ),				       
	      .v_addr      (index                            ),
	      .v_en        ((j == nway_sel)? data_load : 1'b0),
	      .v_read_data (v[j]                             )   
	      );
	   

	   assign cache_hit[j] = tag_val[j] && v[j];//one-hot cache-hit	   	
        end     
   endgenerate

   onehot_to_bin #(
		   .BIN_W (NWAY_W+1)
		   ) 
   onehot_to_bin
     (
      .onehot(cache_hit),
      .bin(nway_hit)
      );
   

   
   always @ (posedge clk)
     cache_read_data [DATA_W -1:0] <= data_read >> DATA_W*(word_select + (2**OFFSET_W)*nway_hit);
   
 `else   

   wire [N_BYTES -1:0] 		      data_line_wstrb;  
   //assign data_line_wstrb = (data_load)? {N_BYTES{R_READY}} : (cache_wstrb & {N_BYTES{cpu_req}});
   assign data_line_wstrb = (write_enable)? (cache_wstrb & {N_BYTES{cpu_req}}) :  {N_BYTES{R_READY}}; 


   genvar 			      i;
   
   generate
      for (i = 0; i < 2**OFFSET_W; i=i+1)
        begin
	   data_memory #(
			 .ADDR_W (NLINE_W) 
			 ) 
	   data_memory 
	       (
		.clk           (clk       ),
		.mem_write_data(write_data),
		.mem_addr      (index     ),
		.mem_en        (((i == word_select) && (data_load || cache_hit))? data_line_wstrb : {N_BYTES{1'b0}}), 
		.mem_read_data (data_read [DATA_W*(i+1)-1: DATA_W*i])   
		);      
        end     
   endgenerate



   tag_memory  #(
		 .ADDR_W (NLINE_W), 
		 .DATA_W (TAG_W) 
		 ) 
   tag_memory 
     (
      .clk           (clk                                         ),
      .tag_write_data(cache_addr[ADDR_W-1:(ADDR_W-TAG_W)]),
      .tag_addr      (index                                       ),
      .tag_en        (data_load                                   ),
      .tag_read_data (tag                                         )                     
      );


   valid_memory #(
		  .ADDR_W (NLINE_W), 
		  .DATA_W (1) 
		  ) 
   valid_memory 
     (
      .clk         (clk       ),
      .reset       (reset   || cache_invalidate  ),
      .v_write_data(data_load ),				        
      .v_addr      (index     ),
      .v_en        (data_load ),
      .v_read_data (v         )   
      );
   

   
   //Using shifts to select the correct Data memory from the cache's Data line, avoiding the use of generate. 
   always @ (posedge clk)
     cache_read_data [DATA_W -1:0] <= data_read >> (word_select * DATA_W);
   
 `endif 

`endif // !`ifdef L1
   

   
   //// read fail Auxiliary FSM states and register //// -> Loading Data (to Data line/Block)
   parameter
     read_stand_by     = 2'd0,
     data_loader_init  = 2'd1,
     data_loader       = 2'd2,
     data_loader_dummy = 2'd3;
   
   
   reg [1:0] read_state;
   reg [1:0] read_next_state;


   //wire [ADDR_W-1-OFFSET_W:0] address = {2'b0 , cache_addr[ADDR_W-1:OFFSET_W+2]};
   
   always @ (posedge clk, posedge reset)
     begin
	
	AR_ADDR  <= {ADDR_W{1'b0}};
	AR_VALID <= 1'b0;
	AR_LEN   <= 8'd0;
	AR_SIZE  <= 3'b000;
	AR_BURST <= 2'b00;
	R_READY  <= 1'b0;
	
	if (reset)
          begin
	     read_state <= read_stand_by; //reset
	     data_load <= 1'b0;
	  end	  
	else
	   
	  case (read_state)
	    
	    read_stand_by://0
	      begin
		 select_counter     <= {OFFSET_W{1'b0}};
		 /*`ifdef L1
		  instr_select_counter <= {I_OFFSET{1'b0}};
		  `endif*/
		 if ((state == read_verification) &&  (~(|cache_hit) && buffer_empty))
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
                 AR_ADDR  <= {cache_addr[ADDR_W -1 : OFFSET_W + 2], {(OFFSET_W+2){1'b0}} }  ; //addr = {tag,index,0...00,00} => word_select = 0...00
                 AR_LEN   <= 2**(OFFSET_W)-1;
`endif
		 //AR_SIZE  <= 3'b010;// 4 bytes
		 AR_SIZE <= $clog2(N_BYTES); // VERIFY BETTER OPTION FOR PARAMETRIZATION
		 AR_BURST <= 2'b01; //INCR
		 data_load <= 1'b1;
		 select_counter <= {OFFSET_W{1'b0}};
		 /*`ifdef L1
		  instr_select_counter <= {I_OFFSET{1'b0}};
		  `endif*/
		 
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
			   /*`ifdef L1
			    instr_select_counter <= instr_select_counter;
			    `endif*/
	                end else begin
			   R_READY <= 1'b1;
			   select_counter <= select_counter + 1; 
			   /*`ifdef L1
			    instr_select_counter <= instr_select_counter + 1;
			    `endif*/                   
			   read_state <= data_loader;
                        end
		      
		   end else begin 
		      R_READY <= 1'b1;   
		      select_counter <= select_counter;
		      /*`ifdef L1
		       instr_select_counter <= instr_select_counter;
		       `endif*/
		      read_state <= data_loader;  
		   end
	      end  
	    
	    default:        
	      begin
		 read_state <= read_stand_by;
	      end
	    
	  endcase // case (state)       
     end                        


   //// buffer FSM states and register ////
   parameter
     buffer_stand_by         = 2'd0,
     buffer_write_validation = 2'd1,
     buffer_write_to_mem     = 2'd2,
     buffer_wait_reply       = 2'd3;  
   
   
   reg [1:0] buffer_state;

   reg 	     buffer_empty_delay;
   
   wire [(N_BYTES) + (ADDR_W - 2) + (DATA_W) -1 :0] buffer_data_out, buffer_data_in; // {wstrb, addr [29:2], word}
   


   always @ (posedge clk, posedge reset)
     begin
	AW_ADDR  <= {(ADDR_W){1'b0}}; //because of the 2 MSB removed
	AW_VALID <= 1'b0;
	W_VALID  <= 1'b0;
	W_STRB   <= {N_BYTES{1'b0}};
	B_READY  <= 1'b1;
	
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
	      begin        //buffer_data_out = {wstrb (size 4), address (size of buffer's WORDSIZE - 4 - word_size), word_size (size of DATA_W)}  
		 W_VALID  <=  1'b1;
		 W_STRB   <=  buffer_data_out [(N_BYTES + ADDR_W -2 + DATA_W) -1 : ADDR_W -2 + DATA_W];
		 W_DATA   <=  buffer_data_out [DATA_W -1 : 0];
		 if (W_READY) buffer_state <= buffer_stand_by;             
		 else         buffer_state <= buffer_write_to_mem;
	      end
	    
	    default:        
	      begin
		 buffer_state <= buffer_stand_by;
	      end
	    
	  endcase    
     end         

   

   assign buffer_data_in = {cache_wstrb, cache_addr[ADDR_W -1: 2], cache_write_data};
   assign buffer_clear   = buffer_empty;//output port
   wire   buffer_read_en = (~buffer_empty) && (buffer_state == buffer_stand_by);
   
   iob_async_fifo #(
		    .DATA_WIDTH (N_BYTES+ADDR_W-2+DATA_W),
		    .ADDRESS_WIDTH (BUFFER_W)//Depth of FIFO
		    ) 
   buffer 
     (
      .rst (reset),
      .data_out (buffer_data_out), 
      .empty(buffer_empty),
      .level_r(),
      .read_en (buffer_read_en),
      .rclk (clk),    
      .data_in (buffer_data_in), 
      .full (buffer_full),
      .level_w(),
      .write_en ((|cache_wstrb) && cpu_req),
      .wclk (clk)
      );



   cache_controller #(
		      .DATA_W(DATA_W)
		      )
   cache_ctrl
     (
      .clk (clk),   
      .ctrl_counter_input (ctrl_counter),
      .ctrl_cache_invalid (cache_invalidate),
      .ctrl_addr          (cache_ctrl_address),
      .ctrl_req_data      (cache_ctrl_requested_data),
      .ctrl_cpu_req       (cache_ctrl_cpu_request),
      .ctrl_ack           (cache_ctrl_acknowledge),
      .ctrl_reset         (reset)
      );
   

   
endmodule // memory_cache


module cache_controller #(
			  parameter DATA_W = 32
			  )
   (
    input 			clk,
    input [`CTRL_COUNTER_W-1:0] ctrl_counter_input, 
    output reg 			ctrl_cache_invalid,
    input [`CTRL_ADDR_W-1:0] 	ctrl_addr,
    output reg [DATA_W-1:0] 	ctrl_req_data,
    input 			ctrl_cpu_req,
    output reg 			ctrl_ack,
    input 			ctrl_reset	   
    );

   reg [DATA_W-1:0] 		instr_hit_cnt, instr_miss_cnt;
   reg [DATA_W-1:0] 		data_read_hit_cnt, data_read_miss_cnt, data_write_hit_cnt, data_write_miss_cnt;
   reg [DATA_W-1:0] 		data_hit_cnt, data_miss_cnt; 
   reg [DATA_W-1:0] 		cache_hit_cnt, cache_miss_cnt;
   reg 				ctrl_counter_reset;
   
`ifdef CTRL_CLK
   reg [2*DATA_W-1:0] 		ctrl_clk_cnt;
   reg 				ctrl_clk_start;
`endif

   always @ (posedge clk, posedge ctrl_reset, posedge ctrl_counter_reset)
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
	
	if (ctrl_reset || ctrl_counter_reset) 
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
	else if (ctrl_counter_input == `INSTR_HIT)
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
     end

`ifdef CTRL_CLK   
   always @(posedge clk, posedge ctrl_counter_reset)
     begin
	ctrl_clk_cnt <= ctrl_clk_cnt;
	if (ctrl_counter_reset)
	  ctrl_clk_cnt <= {(2*DATA_W){1'b0}};
	else if (ctrl_clk_start)
	  ctrl_clk_cnt <= ctrl_clk_cnt +1;
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



module onehot_to_bin #(
		       parameter BIN_W = 2
		       )
   (
    input [2**BIN_W-1:0]   onehot ,
    output reg [BIN_W-1:0] bin 
    );
   always @ (onehot) begin: onehot_to_binary_encoder
      integer i;
      reg [BIN_W-1:0] bin_cnt ;
      bin_cnt = 0;
      for (i=0; i<2**BIN_W; i=i+1)
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
    input 		  clk,
    input 		  reset,
    input 		  write_en,
    output [NWAY_W-1:0]   nway_sel 
    );

   parameter NWAYS = 2**NWAY_W; //number of ways: to simplify in reading the following algorithms
   
   
`ifdef BIT_PLRU
   wire [NWAYS -1:0] 	  mru_output;
   wire [NWAYS -1:0] 	  mru_input = (&(mru_output | cache_hit))? {NWAYS{1'b0}} : mru_output | cache_hit; //When the cache access results in a hit (or access (wish would be 1 in cache_hit even during a read-miss), it will add to the MRU, if after the the OR with Cache_hit, the entire input is 1s, it resets
   wire [NWAYS -1:0] 	  bitplru = (~mru_output); //least recent used
   wire [0:NWAYS -1] 	  bitplru_liw = bitplru [NWAYS -1:0]; //LRU Lower-Index-Way priority
   wire [(NWAYS**2)-1:0]  ext_bitplru;// Extended LRU
   wire [(NWAYS**2)-(NWAYS)-1:0] cmp_bitplru;//Result for the comparision of the LRU values (lru_liw), to choose the lowest index way for replacement. All the results of the comparision will be placed in the wire. This way the comparing all the Ways will take 1 clock cycle, instead of 2**NWAY_W cycles.
   wire [NWAYS-1:0] 		 bitplru_sel;  

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
   wire [NWAYS -1:0] 	    mru_cnt_way_en; //Checks if decrementation should be done, if there isn't any way that received an hit while already being highest priority
   wire 		    mru_cnt_en = &mru_cnt_way_en; //checks if the hit was in a way that wasn't the highest priority
   wire [NWAY_W -1:0] 	    mru_hit_min [NWAYS :0];
   wire [NWAYS -1:0] 	    lru_sel; //selects the way to be replaced, using the LSB of each Way's section
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
      .onehot(bitplru_sel),
`elsif LRU     
      .onehot(lru_sel),
`elsif TREE_PLRU
      .onehot(tplru_sel),
`endif
      .bin(nway_sel)
      );

   
   //Most Recently Used (MRU) memory	   
   valid_memory  #(
		   .ADDR_W (NLINE_W),
`ifdef BIT_PLRU
		   .DATA_W (NWAYS)
`elsif LRU 		
		   .DATA_W (NWAYS*NWAY_W)
`elsif TREE_PLRU
		   .DATA_W (NWAYS-1)
`endif
		   ) 
   mru_memory //simply uses the same format as valid memory
     (
      .clk       (clk            ),
      .reset     (reset          ),
`ifdef TREE_PLRU
      .v_write_data(t_plru       ),
      .v_read_data (t_plru_output),
`else
      .v_write_data(mru_input    ),
      .v_read_data (mru_output   ),			        
`endif      
      .v_addr      (index        ),
      .v_en        (write_en     )
      );
   
endmodule

