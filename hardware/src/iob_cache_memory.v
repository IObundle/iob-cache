`timescale 1ns / 1ps

`include "iob_cache.vh"

module iob_cache_memory
  #(
    parameter FE_ADDR_W   = 32,
    parameter FE_DATA_W   = 32,
    parameter BE_DATA_W = FE_DATA_W,

    parameter NWAYS_W   = 1,
    parameter NLINES_W  = 10,
    parameter WORD_OFFSET_W = 3,
    parameter WTBUF_DEPTH_W = 3,

    parameter WRITE_POL = `WRITE_THROUGH,
    parameter REP_POLICY = `PLRU_TREE,

    parameter CTRL_CACHE = 0,
    parameter CTRL_CNT = 0,

    // Derived parameters DO NOT CHANGE
    parameter FE_NBYTES  = FE_DATA_W/8,
    parameter FE_BYTE_W = $clog2(FE_NBYTES),
    parameter BE_NBYTES = BE_DATA_W/8,
    parameter BE_NBYTES_W = $clog2(BE_NBYTES),
    parameter LINE2BE_W = WORD_OFFSET_W-$clog2(BE_DATA_W/FE_DATA_W)
    )
   (
    input                                                                        clk,
    input                                                                        reset,

    // front-end
    input                                                                        req,
    input [FE_ADDR_W-1:BE_NBYTES_W+LINE2BE_W]                                    addr,
    output [FE_DATA_W-1:0]                                                       rdata,
    output                                                                       ack,

    // stored input value
    input                                                                        req_reg,
    input [FE_ADDR_W-1:FE_BYTE_W]                                                addr_reg,
    input [FE_DATA_W-1:0]                                                        wdata_reg,
    input [FE_NBYTES-1:0]                                                        wstrb_reg,

    // back-end write-channel
    output                                                                       write_req,
    output [FE_ADDR_W-1:FE_BYTE_W + WRITE_POL*WORD_OFFSET_W]                     write_addr,
    output [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 :0] write_wdata,

    // write-through[FE_DATA_W]; write-back[FE_DATA_W*2**WORD_OFFSET_W]
    output [FE_NBYTES-1:0]                                                       write_wstrb,
    input                                                                        write_ack,

    // back-end read-channel
    output                                                                       replace_req,
    output [FE_ADDR_W-1:BE_NBYTES_W+LINE2BE_W]                                   replace_addr,
    input                                                                        replace,
    input                                                                        read_req,
    input [LINE2BE_W-1:0]                                                        read_addr,
    input [BE_DATA_W-1:0]                                                        read_rdata,

    // cache-control
    input                                                                        invalidate,
    output                                                                       wtbuf_full,
    output                                                                       wtbuf_empty,
    output                                                                       write_hit,
    output                                                                       write_miss,
    output                                                                       read_hit,
    output                                                                       read_miss
    );

   localparam TAG_W = FE_ADDR_W - (FE_BYTE_W + WORD_OFFSET_W + NLINES_W);
   localparam NWAYS = 2**NWAYS_W;

   wire                                                                          hit;

   // cache-memory internal signals
   wire [NWAYS-1:0]                                                              way_hit, way_select;

   wire [TAG_W-1:0]                                                              tag = addr_reg[FE_ADDR_W-1 -:TAG_W];                // so the tag doesnt update during ack on a read-access, losing the current hit status (can take the 1 clock-cycle delay)
   wire [NLINES_W-1:0]                                                           index = addr[FE_ADDR_W-TAG_W-1 -: NLINES_W];        // cant wait, doesnt update during a write-access
   wire [NLINES_W-1:0]                                                           index_reg = addr_reg[FE_ADDR_W-TAG_W-1 -:NLINES_W]; // cant wait, doesnt update during a write-access
   wire [WORD_OFFSET_W-1:0]                                                      offset = addr_reg[FE_BYTE_W +: WORD_OFFSET_W];      // so the offset doesnt update during ack on a read-access (can take the 1 clock-cycle delay)
   wire [NWAYS*(2**WORD_OFFSET_W)*FE_DATA_W-1:0]                                 line_rdata;
   wire [NWAYS*TAG_W-1:0]                                                        line_tag;
   reg [NWAYS*(2**NLINES_W)-1:0]                                                 v_reg;
   reg [NWAYS-1:0]                                                               v;

   reg [(2**WORD_OFFSET_W)*FE_NBYTES-1:0]                                        line_wstrb;

   wire                                                                          write_access = |wstrb_reg & req_reg;
   wire                                                                          read_access = ~|wstrb_reg & req_reg;//signal mantains the access 1 addition clock-cycle after ack is asserted

   // back-end write channel
   wire                                                                          buffer_empty, buffer_full;
   wire [FE_NBYTES+(FE_ADDR_W-FE_BYTE_W)+(FE_DATA_W)-1:0]                        buffer_dout;

   // for write-back write-allocate only
   reg [NWAYS-1:0]                                                               dirty;
   reg [NWAYS*(2**NLINES_W)-1:0]                                                 dirty_reg;

   generate
      if (WRITE_POL == `WRITE_THROUGH) begin
         localparam FIFO_DATA_W = FE_ADDR_W-FE_BYTE_W + FE_DATA_W + FE_NBYTES;
         localparam FIFO_ADDR_W = WTBUF_DEPTH_W;

         wire mem_w_en;
         wire [FIFO_ADDR_W-1:0] mem_w_addr;
         wire [FIFO_DATA_W-1:0] mem_w_data;

         wire mem_r_en;
         wire [FIFO_ADDR_W-1:0] mem_r_addr;
         wire [FIFO_DATA_W-1:0] mem_r_data;

         // FIFO memory
         iob_ram_2p
           #(
             .DATA_W(FIFO_DATA_W),
             .ADDR_W(FIFO_ADDR_W)
             )
         iob_ram_2p0
           (
            .clk    (clk),

            .w_en   (mem_w_en),
            .w_addr (mem_w_addr),
            .w_data (mem_w_data),

            .r_en   (mem_r_en),
            .r_addr (mem_r_addr),
            .r_data (mem_r_data)
            );

         iob_fifo_sync
           #(
             .R_DATA_W (FIFO_DATA_W),
             .W_DATA_W (FIFO_DATA_W),
             .ADDR_W   (FIFO_ADDR_W)
             )
         write_throught_buffer
           (
            .clk     (clk),
            .rst     (reset),
            .arst    (reset),

            .ext_mem_w_en   (mem_w_en),
            .ext_mem_w_addr (mem_w_addr),
            .ext_mem_w_data (mem_w_data),

            .ext_mem_r_en   (mem_r_en),
            .ext_mem_r_addr (mem_r_addr),
            .ext_mem_r_data (mem_r_data),

            .level   (),

            .r_data  (buffer_dout),
            .r_empty (buffer_empty),
            .r_en    (write_ack),

            .w_data  ({addr_reg,wdata_reg,wstrb_reg}),
            .w_full  (buffer_full),
            .w_en    (write_access & ack)
            );

         // buffer status
         assign wtbuf_full  = buffer_full;
         assign wtbuf_empty = buffer_empty & write_ack & ~write_req;

         // back-end write channel
         assign write_req   = ~buffer_empty;
         assign write_addr  = buffer_dout[FE_NBYTES + FE_DATA_W +: FE_ADDR_W - FE_BYTE_W];
         assign write_wdata = buffer_dout[FE_NBYTES             +: FE_DATA_W            ];
         assign write_wstrb = buffer_dout[0                     +: FE_NBYTES            ];

         // back-end read channel
         assign replace_req  = (~hit & read_access & ~replace) & (buffer_empty & write_ack);
         assign replace_addr = addr[FE_ADDR_W-1:BE_NBYTES_W+LINE2BE_W];
      end else begin // if (WRITE_POL == WRITE_BACK)
         // back-end write channel
         assign write_wstrb = {FE_NBYTES{1'bx}};
         // write_req, write_addr and write_wdata assigns are generated bellow (dependencies)

         // back-end read channel
         assign replace_req = (~|way_hit) & (write_ack) & req_reg & ~replace;
         assign replace_addr = addr[FE_ADDR_W-1:BE_NBYTES_W+LINE2BE_W];

         // buffer status (non-existant)
`ifdef CTRL_IO
         assign wtbuf_full = 1'b0;
         assign wtbuf_empty = 1'b1;
`else
         assign wtbuf_full = 1'bx;
         assign wtbuf_empty = 1'bx;
`endif
      end
   endgenerate

   //////////////////////////////////////////////////////
   // Read-After-Write (RAW) Hazard (pipeline) control
   //////////////////////////////////////////////////////
   wire                                                     raw;
   reg                                                      write_hit_prev;
   reg [WORD_OFFSET_W-1:0]                                  offset_prev;
   reg [NWAYS-1:0]                                          way_hit_prev;

   generate
      if (WRITE_POL == `WRITE_THROUGH) begin
         always @(posedge clk) begin
            write_hit_prev <= write_access & (|way_hit);
            // previous write position
            offset_prev <= offset;
            way_hit_prev <= way_hit;
         end
         assign raw = write_hit_prev & (way_hit_prev == way_hit) & (offset_prev == offset);
      end else begin // if (WRITE_POL == WRITE_BACK)
         always @(posedge clk) begin
            write_hit_prev <= write_access; // all writes will have the data in cache in the end
            // previous write position
            offset_prev <= offset;
            way_hit_prev <= way_hit;
         end
         assign raw = write_hit_prev & (way_hit_prev == way_hit) & (offset_prev == offset) & read_access; // without read_access it is an infinite replacement loop
      end
   endgenerate

   ///////////////////////////////////////////////////////////////
   // Hit signal: data available and in the memory's output
   ///////////////////////////////////////////////////////////////
   assign hit = |way_hit & ~replace & (~raw);

   /////////////////////////////////
   // front-end ACK signal
   /////////////////////////////////
   generate
      if (WRITE_POL == `WRITE_THROUGH)
        assign ack = (hit & read_access) | (~buffer_full & write_access);
      else // if (WRITE_POL == WRITE_BACK)
        assign ack = hit & req_reg;
   endgenerate

   // cache-control hit-miss counters enables
   generate
      if (CTRL_CACHE & CTRL_CNT) begin
         // cache-control hit-miss counters enables
         assign write_hit  = ack & ( hit & write_access);
         assign write_miss = ack & (~hit & write_access);
         assign read_hit   = ack & ( hit &  read_access);
         assign read_miss  = replace_req;//will also subtract read_hit
      end else begin
         assign write_hit  = 1'bx;
         assign write_miss = 1'bx;
         assign read_hit   = 1'bx;
         assign read_miss  = 1'bx;
      end
   endgenerate

   /////////////////////////////////////////
   // Memories implementation configurations
   /////////////////////////////////////////
   genvar                                                   i,j,k;
   generate
      // Data-Memory
      for (k=0; k < NWAYS; k=k+1) begin : n_ways_block
        for (j=0; j < 2**LINE2BE_W; j=j+1) begin : line2mem_block
          for (i=0; i < BE_DATA_W/FE_DATA_W; i=i+1) begin : BE_FE_block
             iob_gen_sp_ram
               #(
                 .DATA_W(FE_DATA_W),
                 .ADDR_W(NLINES_W)
                 )
             cache_memory
                 (
                  .clk (clk),
                  .en  (req),
                  .we ({FE_NBYTES{way_hit[k]}} & line_wstrb[(j*(BE_DATA_W/FE_DATA_W)+i)*FE_NBYTES +: FE_NBYTES]),
                  .addr((write_access & way_hit[k] & ((j*(BE_DATA_W/FE_DATA_W)+i) == offset))? index_reg : index),
                  .data_in ((replace)? read_rdata[i*FE_DATA_W +: FE_DATA_W] : wdata_reg),
                  .data_out(line_rdata[(k*(2**WORD_OFFSET_W)+j*(BE_DATA_W/FE_DATA_W)+i)*FE_DATA_W +: FE_DATA_W])
                  );
          end
        end
      end

      // Cache Line Write Strobe
      if (LINE2BE_W > 0) begin
         always @*
           if (replace)
             line_wstrb = {BE_NBYTES{read_req}} << (read_addr*BE_NBYTES); // line-replacement: read_addr indexes the words in cache-line
           else
             line_wstrb = (wstrb_reg & {FE_NBYTES{write_access}}) << (offset*FE_NBYTES);
      end else begin
         always @*
           if (replace)
             line_wstrb = {BE_NBYTES{read_req}}; // line-replacement: mem's word replaces entire line
           else
             line_wstrb = (wstrb_reg & {FE_NBYTES{write_access}}) << (offset*FE_NBYTES);
      end

      // Valid-Tag memories & replacement-policy
      if (NWAYS > 1) begin
         wire [NWAYS_W-1:0] way_hit_bin, way_select_bin; // reason for the 2 generates for single vs multiple ways
         // valid-memory
         always @(posedge clk, posedge reset) begin
            if (reset)
              v_reg <= 0;
            else if (invalidate)
              v_reg <= 0;
            else if (replace_req)
              v_reg <= v_reg | (1<<(way_select_bin*(2**NLINES_W) + index_reg));
            else
              v_reg <= v_reg;
         end

         for(k=0; k < NWAYS; k=k+1) begin : tag_mem_block
            // valid-memory output stage register - 1 c.c. read-latency (cleaner simulation during rep.)
            always @(posedge clk)
              if (invalidate)
                v[k] <= 0;
              else
                v[k] <= v_reg [(2**NLINES_W)*k + index];

            // tag-memory
            iob_ram_sp
              #(
                .DATA_W(TAG_W),
                .ADDR_W(NLINES_W)
                )
            tag_memory
              (
               .clk (clk                         ),
               .en  (req                         ),
               .we  (way_select[k] & replace_req ),
               .addr(index                       ),
               .din (tag                         ),
               .dout(line_tag[TAG_W*k +: TAG_W]  )
               );

              // Way hit signal - hit or replacement
            assign way_hit[k] = (tag == line_tag[TAG_W*k +: TAG_W]) & v[k];
         end
         // Read Data Multiplexer
         assign rdata [FE_DATA_W-1:0] = line_rdata >> FE_DATA_W*(offset + (2**WORD_OFFSET_W)*way_hit_bin);

         // replacement-policy module
         iob_cache_replacement_policy
           #(
             .N_WAYS (NWAYS),
             .NLINES_W(NLINES_W),
             .REP_POLICY(REP_POLICY)
             )
         replacement_policy_algorithm
           (
            .clk       (clk             ),
            .reset     (reset|invalidate),
            .write_en  (ack           ),
            .way_hit   (way_hit         ),
            .line_addr (index_reg       ),
            .way_select(way_select      ),
            .way_select_bin(way_select_bin)
            );

         // onehot-to-binary for way-hit
         iob_cache_onehot_to_bin
           #(NWAYS_W)
         way_hit_encoder
           (
            .onehot(way_hit[NWAYS-1:1]),
            .bin   (way_hit_bin)
            );

         // dirty-memory
         if (WRITE_POL == `WRITE_BACK) begin
            always @(posedge clk, posedge reset) begin
               if (reset)
                 dirty_reg <= 0;
               else if (write_req)
                 dirty_reg <= dirty_reg & ~(1<<(way_select_bin*(2**NLINES_W) + index_reg)); // updates position with 0
               else if (write_access & hit)
                 dirty_reg <= dirty_reg |  (1<<(way_hit_bin*(2**NLINES_W) + index_reg)); // updates position with 1
               else
                 dirty_reg <= dirty_reg;
            end

            for(k=0; k < NWAYS; k=k+1) begin : dirty_block
               // valid-memory output stage register - 1 c.c. read-latency (cleaner simulation during rep.)
               always @(posedge clk)
                 dirty[k] <= dirty_reg [(2**NLINES_W)*k + index];
            end

            // flush line
            assign write_req = req_reg & ~(|way_hit) & (way_select == dirty); //flush if there is not a hit, and the way selected is dirty
            wire [TAG_W-1:0] tag_flush = line_tag >> (way_select_bin*TAG_W);      //auxiliary wire
            assign write_addr  = {tag_flush, index_reg};                          //the position of the current block in cache (not of the access)
            assign write_wdata = line_rdata >> (way_select_bin*FE_DATA_W*(2**WORD_OFFSET_W));

         end
      end else begin // (NWAYS = 1)
         // valid-memory
         always @(posedge clk, posedge reset) begin
            if (reset)
              v_reg <= 0;
            else if (invalidate)
              v_reg <= 0;
            else if (replace_req)
              v_reg <= v_reg | (1 << index);
            else
              v_reg <= v_reg;
         end

         // valid-memory output stage register - 1 c.c. read-latency (cleaner simulation during rep.)
         always @(posedge clk)
           if (invalidate)
             v <= 0;
           else
             v <= v_reg [index];

         // tag-memory
         iob_ram_sp
           #(
             .DATA_W(TAG_W),
             .ADDR_W(NLINES_W)
             )
         tag_memory
           (
            .clk (clk),
            .en  (req),
            .we  (replace_req),
            .addr(index),
            .din (tag),
            .dout(line_tag)
            );

           // Cache hit signal that indicates which way has had the hit (also during replacement)
           assign way_hit = (tag == line_tag) & v;

           // Read Data Multiplexer
           assign rdata [FE_DATA_W-1:0] = line_rdata >> FE_DATA_W*offset;

           // dirty-memory
           if (WRITE_POL == `WRITE_BACK) begin
              // dirty-memory
              always @(posedge clk, posedge reset) begin
                 if (reset)
                   dirty_reg <= 0;
                 else if (write_req)
                   dirty_reg <= dirty_reg & ~(1<<(index_reg)); // updates postion with 0
                 else if (write_access & hit)
                   dirty_reg <= dirty_reg | (1<<(index_reg));  // updates position with 1 (needs to be index_reg otherwise updates the new index if the previous access was a write)
                 else
                   dirty_reg <= dirty_reg;
              end

              always @(posedge clk)
                dirty <= dirty_reg [index];

              // flush line
              assign write_req = write_access & ~(way_hit) & dirty; // flush if there is not a hit, and is dirty
              assign write_addr  = {line_tag, index};               // the position of the current block in cache (not of the access)
              assign write_wdata = line_rdata;
           end
      end
   endgenerate

endmodule

/*---------------------------------*/
/* Byte-width generable iob-sp-ram */
/*---------------------------------*/

// For cycle that generated byte-width (single enable) single-port SRAM
// older synthesis tool may require this approch

module iob_gen_sp_ram
  #(
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

   genvar                i;
   generate
      for (i=0; i < (DATA_W/8); i=i+1) begin : ram
         iob_ram_sp
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
             .dout(data_out[8*i +: 8]),
             .din (data_in [8*i +: 8])
             );
        end
   endgenerate

endmodule
