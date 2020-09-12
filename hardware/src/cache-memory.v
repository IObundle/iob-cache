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
     input [FE_ADDR_W-1:FE_BYTE_W + LINE2MEM_W] addr,
     input [FE_DATA_W-1:0]                      wdata,
     input [FE_NBYTES-1:0]                      wstrb,
     output [FE_DATA_W-1:0]                     rdata,
     output                                     ready,
     //stored input value
     input                                      valid_reg,
     input [FE_ADDR_W-1:FE_BYTE_W]              addr_reg,
     input [FE_DATA_W-1:0]                      wdata_reg,
     input [FE_NBYTES-1:0]                      wstrb_reg,
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
   reg [N_WAYS*(2**LINE_OFF_W)-1:0]             v_reg;
   reg [N_WAYS-1:0]                             v;

   //always @ (posedge clk)
   //  v <= line_v;

   
   
   
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
   

   iob_sync_fifo #(
		   .DATA_WIDTH    (FE_ADDR_W-FE_BYTE_W + FE_DATA_W + FE_NBYTES),
		   .ADDRESS_WIDTH (WTBUF_DEPTH_W)
		   ) 
   write_throught_buffer 
     (
      .rst     (reset),
      .clk (clk),
      .fifo_ocupancy (),       
      .data_out(buffer_dout), 
      .empty   (buffer_empty),
      .read_en (write_ready),  
      .data_in ({addr_reg,wdata_reg,wstrb_reg}), 
      .full    (buffer_full),
      .write_en(write_access & ready)
      );
   
   //back-end read channel
   assign replace_valid = (~hit & read_access_reg & replace_ready) & (buffer_empty & write_ready);
   assign replace_addr  = addr[FE_ADDR_W -1:BE_BYTE_W+LINE2MEM_W];


   //RAW hazard prevention
   reg                                                      RAW_prev;

   always @(posedge clk)
     RAW_prev <= ~(write_access_reg & hit);
   
   //front-end READY signal
   assign ready = (hit & (read_access_reg) & (replace_ready) & RAW_prev) | (~buffer_full & (write_access_reg));
   // read section needs to be the registered, so it doesn't change the moment ready asserts and updates the input. Write doesn't update on the same cycle as ready asserts, and in the next clock cycle, will have the next input.

   //cache-control hit-miss counters enables
   assign write_hit  = ready & ( hit & write_access_reg);
   assign write_miss = ready & (~hit & write_access_reg);
   assign read_hit   = ready & ( hit &  read_access_reg);
   assign read_miss  = ready & (~hit &  read_access_reg);
   
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
                   .valid     (valid),
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


                

                always @ (posedge clk, posedge reset)
                  begin
                     if (reset | invalidate)
                       v_reg <= 0;
                     else
                       if(replace_valid)
                         v_reg <= v_reg | (1<<(way_select_bin*(2**LINE_OFF_W) + index));
                       else
                         v_reg <= v_reg;
                  end
                
                
                
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

                     
                     always @(posedge clk)
                       v[k] <= v_reg [(2**LINE_OFF_W)*k + index];
                     
                     
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





/*---------------------------------*/
/* Byte-width generable iob-sp-ram */
/*---------------------------------*/

//For cycle that generated byte-width single-port SRAM
//older synthesis tool may require this approch

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
