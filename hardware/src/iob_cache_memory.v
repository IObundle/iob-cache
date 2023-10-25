`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache_swreg_def.vh"

module iob_cache_memory #(
   parameter FE_ADDR_W = `IOB_CACHE_FE_ADDR_W,
   parameter FE_DATA_W = `IOB_CACHE_FE_DATA_W,
   parameter BE_ADDR_W = `IOB_CACHE_BE_ADDR_W,
   parameter BE_DATA_W = `IOB_CACHE_BE_DATA_W,

   parameter NWAYS_W       = `IOB_CACHE_NWAYS_W,
   parameter NLINES_W      = `IOB_CACHE_NLINES_W,
   parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
   parameter WTBUF_DEPTH_W = `IOB_CACHE_WTBUF_DEPTH_W,

   parameter WRITE_POL  = `IOB_CACHE_WRITE_THROUGH,
   parameter REP_POLICY = `IOB_CACHE_PLRU_TREE,

   parameter USE_CTRL     = `IOB_CACHE_USE_CTRL,
   parameter USE_CTRL_CNT = `IOB_CACHE_USE_CTRL_CNT,
   //derived parameters
   parameter FE_NBYTES    = FE_DATA_W / 8,
   parameter FE_NBYTES_W  = $clog2(FE_NBYTES),
   parameter BE_NBYTES    = BE_DATA_W / 8,
   parameter BE_NBYTES_W  = $clog2(BE_NBYTES),
   parameter LINE2BE_W    = WORD_OFFSET_W - $clog2(BE_DATA_W / FE_DATA_W)
) (
   input clk_i,
   input cke_i,
   input reset_i,

   // front-end
   input                                      req_i,
   input  [FE_ADDR_W-1:BE_NBYTES_W+LINE2BE_W] addr_i,
   output [                    FE_DATA_W-1:0] rdata_o,
   output                                     ack_o,

   // stored input value
   input                           req_reg_i,
   input [FE_ADDR_W-1:FE_NBYTES_W] addr_reg_i,
   input [          FE_DATA_W-1:0] wdata_reg_i,
   input [          FE_NBYTES-1:0] wstrb_reg_i,

   // back-end write-channel
   output                                                                        write_req_o,
   output [                   FE_ADDR_W-1:FE_NBYTES_W + WRITE_POL*WORD_OFFSET_W] write_addr_o,
   output [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFFSET_W)-FE_DATA_W)-1 : 0] write_wdata_o,

   // write-through[DATA_W]; write-back[DATA_W*2**WORD_OFFSET_W]
   output [FE_NBYTES-1:0] write_wstrb_o,
   input                  write_ack_i,

   // back-end read-channel
   output                                     replace_req_o,
   output [FE_ADDR_W-1:BE_NBYTES_W+LINE2BE_W] replace_addr_o,
   input                                      replace_i,
   input                                      read_req_i,
   input  [                    LINE2BE_W-1:0] read_addr_i,
   input  [                    BE_DATA_W-1:0] read_rdata_i,

   // cache-control
   input  invalidate_i,
   output wtbuf_full_o,
   output wtbuf_empty_o,
   output write_hit_o,
   output write_miss_o,
   output read_hit_o,
   output read_miss_o
);

   localparam TAG_W = FE_ADDR_W - (FE_NBYTES_W + WORD_OFFSET_W + NLINES_W);
   localparam NWAYS = 2 ** NWAYS_W;

   wire hit;

   // cache-memory internal signals
   wire [NWAYS-1:0] way_hit, way_select;

   wire [TAG_W-1:0]            tag = addr_reg_i[FE_ADDR_W-1 -: TAG_W]; // so the tag doesnt update during ack on a read-access, losing the current hit status (can take the 1 clock-cycle delay)
   wire [NWAYS_W+NLINES_W-1:0] index = addr_i[FE_ADDR_W-TAG_W-1 -: NLINES_W]; // cant wait, doesnt update during a write-access
   wire [NWAYS_W+NLINES_W-1:0] index_reg = addr_reg_i[FE_ADDR_W-TAG_W-1 -:NLINES_W]; // cant wait, doesnt update during a write-access
   wire [WORD_OFFSET_W-1:0]    offset = addr_reg_i[FE_NBYTES_W +: WORD_OFFSET_W]; // so the offset doesnt update during ack on a read-access (can take the 1 clock-cycle delay)
   wire [NWAYS*(2**WORD_OFFSET_W)*FE_DATA_W-1:0] line_rdata;
   wire [NWAYS*TAG_W-1:0] line_tag;
   reg [NWAYS*(2**NLINES_W)-1:0] v_reg;
   reg [NWAYS-1:0] v;

   reg [(2**WORD_OFFSET_W)*FE_NBYTES-1:0] line_wstrb;

   wire write_access = |wstrb_reg_i & req_reg_i;
   wire read_access = ~|wstrb_reg_i & req_reg_i;
   //signal mantains the access 1 addition clock-cycle after ack is asserted

   // back-end write channel
   wire buffer_empty, buffer_full;
   wire [FE_NBYTES+(FE_ADDR_W-FE_NBYTES_W)+(FE_DATA_W)-1:0] buffer_dout;

   // for write-back write-allocate only
   reg  [                                        NWAYS-1:0] dirty;
   reg  [                          NWAYS*(2**NLINES_W)-1:0] dirty_reg;

   generate
      if (WRITE_POL == `IOB_CACHE_WRITE_THROUGH) begin : g_write_through
         localparam FIFO_DATA_W = FE_ADDR_W - FE_NBYTES_W + FE_DATA_W + FE_NBYTES;
         localparam FIFO_ADDR_W = WTBUF_DEPTH_W;

         wire                   mem_clk;
         wire                   mem_arst;
         wire                   mem_cke;

         wire                   mem_w_en;
         wire [FIFO_ADDR_W-1:0] mem_w_addr;
         wire [FIFO_DATA_W-1:0] mem_w_data;

         wire                   mem_r_en;
         wire [FIFO_ADDR_W-1:0] mem_r_addr;
         wire [FIFO_DATA_W-1:0] mem_r_data;

         // FIFO memory
         iob_ram_2p #(
            .DATA_W(FIFO_DATA_W),
            .ADDR_W(FIFO_ADDR_W)
         ) iob_ram_2p0 (
            .clk_i(clk_i),

            .w_en_i  (mem_w_en),
            .w_addr_i(mem_w_addr),
            .w_data_i(mem_w_data),

            .r_en_i  (mem_r_en),
            .r_addr_i(mem_r_addr),
            .r_data_o(mem_r_data)
         );

         iob_fifo_sync #(
            .R_DATA_W(FIFO_DATA_W),
            .W_DATA_W(FIFO_DATA_W),
            .ADDR_W  (FIFO_ADDR_W)
         ) write_throught_buffer (
            .clk_i (clk_i),
            .rst_i (reset_i),
            .arst_i(reset_i),
            .cke_i (1'b1),

            .ext_mem_clk_o   (mem_clk),

            .ext_mem_w_en_o  (mem_w_en),
            .ext_mem_w_addr_o(mem_w_addr),
            .ext_mem_w_data_o(mem_w_data),

            .ext_mem_r_en_o  (mem_r_en),
            .ext_mem_r_addr_o(mem_r_addr),
            .ext_mem_r_data_i(mem_r_data),

            .level_o(),

            .r_data_o (buffer_dout),
            .r_empty_o(buffer_empty),
            .r_en_i   (write_ack_i),

            .w_data_i({addr_reg_i, wdata_reg_i, wstrb_reg_i}),
            .w_full_o(buffer_full),
            .w_en_i  (write_access & ack_o)
         );

         // buffer status
         assign wtbuf_full_o   = buffer_full;
         assign wtbuf_empty_o  = buffer_empty & write_ack_i & ~write_req_o;

         // back-end write channel
         assign write_req_o    = ~buffer_empty;
         assign write_addr_o   = buffer_dout[FE_NBYTES+FE_DATA_W+:FE_ADDR_W-FE_NBYTES_W];
         assign write_wdata_o  = buffer_dout[FE_NBYTES+:FE_DATA_W];
         assign write_wstrb_o  = buffer_dout[0+:FE_NBYTES];

         // back-end read channel
         assign replace_req_o  = (~hit & read_access & ~replace_i) & (buffer_empty & write_ack_i);
         assign replace_addr_o = addr_i[FE_ADDR_W-1:BE_NBYTES_W+LINE2BE_W];
      end else begin : g_write_back
         // if (WRITE_POL == WRITE_BACK)
         // back-end write channel
         assign write_wstrb_o  = {FE_NBYTES{1'bx}};
         // write_req_o, write_addr_o and write_wdata_o assigns are generated bellow (dependencies)

         // back-end read channel
         assign replace_req_o  = (~|way_hit) & (write_ack_i) & req_reg_i & ~replace_i;
         assign replace_addr_o = addr_i[FE_ADDR_W-1:BE_NBYTES_W+LINE2BE_W];
      end
   endgenerate

   //////////////////////////////////////////////////////
   // Read-After-Write (RAW) Hazard (pipeline) control
   //////////////////////////////////////////////////////
   wire                     raw;
   reg                      write_hit_prev;
   reg  [WORD_OFFSET_W-1:0] offset_prev;
   reg  [        NWAYS-1:0] way_hit_prev;

   generate
      if (WRITE_POL == `IOB_CACHE_WRITE_THROUGH) begin : g_write_through_on_RAW
         always @(posedge clk_i) begin
            write_hit_prev <= write_access & (|way_hit);
            // previous write position
            offset_prev    <= offset;
            way_hit_prev   <= way_hit;
         end
         assign raw = write_hit_prev & (way_hit_prev == way_hit) & (offset_prev == offset);
      end else begin : g_write_back_on_RAW
         // if (WRITE_POL == WRITE_BACK)
         always @(posedge clk_i) begin
            // all writes will have the data in cache in the end
            write_hit_prev <= write_access;
            // previous write position
            offset_prev    <= offset;
            way_hit_prev   <= way_hit;
         end
         assign raw = write_hit_prev & (way_hit_prev == way_hit) & (offset_prev == offset) & read_access;
         // without read_access it is an infinite replacement loop
      end
   endgenerate

   ///////////////////////////////////////////////////////////////
   // Hit signal: data available and in the memory's output
   ///////////////////////////////////////////////////////////////
   assign hit = |way_hit & ~replace_i & (~raw);

   /////////////////////////////////
   // front-end ACK signal
   /////////////////////////////////
   generate
      if (WRITE_POL == `IOB_CACHE_WRITE_THROUGH)
         assign ack_o = (hit & read_access) | (~buffer_full & write_access);
      else  // if (WRITE_POL == WRITE_BACK)
         assign ack_o = hit & req_reg_i;
   endgenerate

   // cache-control hit-miss counters enables
   generate
      if (USE_CTRL & USE_CTRL_CNT) begin : g_ctrl_cnt
         // cache-control hit-miss counters enables
         assign write_hit_o  = ack_o & (hit & write_access);
         assign write_miss_o = ack_o & (~hit & write_access);
         assign read_hit_o   = ack_o & (hit & read_access);
         assign read_miss_o  = replace_req_o;  //will also subtract read_hit_o
      end else begin : g_no_ctrl_cnt
         assign write_hit_o  = 1'bx;
         assign write_miss_o = 1'bx;
         assign read_hit_o   = 1'bx;
         assign read_miss_o  = 1'bx;
      end
   endgenerate

   /////////////////////////////////////////
   // Memories implementation configurations
   /////////////////////////////////////////
   genvar i, j, k;
   generate
      // Data-Memory
      for (k = 0; k < NWAYS; k = k + 1) begin : g_n_ways_block
         for (j = 0; j < 2 ** LINE2BE_W; j = j + 1) begin : g_line2mem_block
            for (i = 0; i < BE_DATA_W / FE_DATA_W; i = i + 1) begin : g_BE_block
               iob_gen_sp_ram #(
                  .DATA_W(FE_DATA_W),
                  .ADDR_W(NLINES_W)
               ) cache_memory (
                  .clk_i(clk_i),
                  .en_i(req_i),
                  .we_i ({FE_NBYTES{way_hit[k]}} & line_wstrb[(j*(BE_DATA_W/FE_DATA_W)+i)*FE_NBYTES +: FE_NBYTES]),
                  .addr_i((write_access & way_hit[k] & ((j*(BE_DATA_W/FE_DATA_W)+i) == offset))? index_reg[NLINES_W-1:0] : index[NLINES_W-1:0]),
                  .data_i((replace_i) ? read_rdata_i[i*FE_DATA_W+:FE_DATA_W] : wdata_reg_i),
                  .data_o(line_rdata[(k*(2**WORD_OFFSET_W)+j*(BE_DATA_W/FE_DATA_W)+i)*FE_DATA_W+:FE_DATA_W])
               );
            end
         end
      end

      // Cache Line Write Strobe
      if (LINE2BE_W > 0) begin : g_line2be_w
         always @* begin
            if (replace_i) begin
               // line-replacement: read_addr_i indexes the words in cache-line
               line_wstrb = {BE_NBYTES{read_req_i}} << (read_addr_i * BE_NBYTES);
            end else begin
               line_wstrb = (wstrb_reg_i & {FE_NBYTES{write_access}}) << (offset * FE_NBYTES);
            end
         end
      end else begin : g_no_line2be_w
         always @* begin
            if (replace_i) begin
               // line-replacement: mem's word replaces entire line
               line_wstrb = {BE_NBYTES{read_req_i}};
            end else begin
               line_wstrb = (wstrb_reg_i & {FE_NBYTES{write_access}}) << (offset * FE_NBYTES);
            end
         end
      end

      // Valid-Tag memories & replacement-policy
      if (NWAYS > 1) begin : g_nways
         // reason for the 2 generates for single vs multiple ways
         wire [NWAYS_W-1:0] way_hit_bin, way_select_bin;
         // valid-memory
         always @(posedge clk_i, posedge reset_i) begin
            if (reset_i) v_reg <= 0;
            else if (invalidate_i) v_reg <= 0;
            else if (replace_req_o)
               v_reg <= v_reg | (1 << (way_select_bin * (2 ** NLINES_W) + index_reg));
            else v_reg <= v_reg;
         end

         for (k = 0; k < NWAYS; k = k + 1) begin : g_tag_mem_block
            // valid-memory output stage register - 1 c.c. read-latency (cleaner simulation during rep.)
            always @(posedge clk_i)
               if (invalidate_i) v[k] <= 0;
               else v[k] <= v_reg[(2**NLINES_W)*k+index];

            // tag-memory
            iob_ram_sp #(
               .DATA_W(TAG_W),
               .ADDR_W(NLINES_W)
            ) tag_memory (
               .clk_i (clk_i),
               .en_i  (req_i),
               .we_i  (way_select[k] & replace_req_o),
               .addr_i(index[NLINES_W-1:0]),
               .d_i   (tag),
               .d_o   (line_tag[TAG_W*k+:TAG_W])
            );

            // Way hit signal - hit or replacement
            assign way_hit[k] = (tag == line_tag[TAG_W*k+:TAG_W]) & v[k];
         end
         // Read Data Multiplexer
         wire [NWAYS*(2**WORD_OFFSET_W)*FE_DATA_W-1:0] line_rdata_tmp = line_rdata >> (FE_DATA_W*(offset + (2**WORD_OFFSET_W)*way_hit_bin));
         assign rdata_o[FE_DATA_W-1:0] = line_rdata_tmp[FE_DATA_W-1:0];

         // replacement-policy module
         iob_cache_replacement_policy #(
            .N_WAYS    (NWAYS),
            .NLINES_W  (NLINES_W),
            .REP_POLICY(REP_POLICY)
         ) replacement_policy_algorithm (
            .clk_i         (clk_i),
            .cke_i         (cke_i),
            .reset_i         (reset_i | invalidate_i),
            .write_en_i      (ack_o),
            .way_hit_i       (way_hit),
            .line_addr_i     (index_reg[NLINES_W-1:0]),
            .way_select_o    (way_select),
            .way_select_bin_o(way_select_bin)
         );

         // onehot-to-binary for way-hit
         iob_cache_onehot_to_bin #(
            .BIN_W(NWAYS_W)
         ) way_hit_encoder (
            .onehot_i(way_hit[NWAYS-1:1]),
            .bin_o   (way_hit_bin)
         );

         // dirty-memory
         if (WRITE_POL == `IOB_CACHE_WRITE_BACK) begin : g_write_back
            always @(posedge clk_i, posedge reset_i) begin
               if (reset_i) dirty_reg <= 0;
               else if (write_req_o)
                  dirty_reg <= dirty_reg & ~(1<<(way_select_bin*(2**NLINES_W) + index_reg)); // updates position with 0
               else if (write_access & hit)
                  dirty_reg <= dirty_reg |  (1<<(way_hit_bin*(2**NLINES_W) + index_reg)); // updates position with 1
               else dirty_reg <= dirty_reg;
            end

            for (k = 0; k < NWAYS; k = k + 1) begin : g_dirty_block
               // valid-memory output stage register - 1 c.c. read-latency (cleaner simulation during rep.)
               always @(posedge clk_i) dirty[k] <= dirty_reg[(2**NLINES_W)*k+index];
            end

            // flush line
            assign write_req_o = req_reg_i & ~(|way_hit) & (way_select == dirty); //flush if there is not a hit, and the way selected is dirty
            wire [TAG_W-1:0] tag_flush = line_tag >> (way_select_bin * TAG_W);  //auxiliary wire
            assign write_addr_o = {
               tag_flush, index_reg
            };  //the position of the current block in cache (not of the access)
            assign write_wdata_o = line_rdata >> (way_select_bin * FE_DATA_W * (2 ** WORD_OFFSET_W));

         end
      end else begin : g_one_way  // (NWAYS = 1)
         // valid-memory
         always @(posedge clk_i, posedge reset_i) begin
            if (reset_i) v_reg <= 0;
            else if (invalidate_i) v_reg <= 0;
            else if (replace_req_o) v_reg <= v_reg | (1 << index);
            else v_reg <= v_reg;
         end

         // valid-memory output stage register - 1 c.c. read-latency (cleaner simulation during rep.)
         always @(posedge clk_i) begin
            if (invalidate_i) v <= 0;
            else v <= v_reg[index];
         end

         // tag-memory
         iob_ram_sp #(
            .DATA_W(TAG_W),
            .ADDR_W(NLINES_W)
         ) tag_memory (
            .clk_i (clk_i),
            .en_i  (req_i),
            .we_i  (replace_req_o),
            .addr_i(index),
            .d_i   (tag),
            .d_o   (line_tag)
         );

         // Cache hit signal that indicates which way has had the hit (also during replacement)
         assign way_hit              = (tag == line_tag) & v;

         // Read Data Multiplexer
         assign rdata_o[FE_DATA_W-1:0] = line_rdata >> FE_DATA_W * offset;

         // dirty-memory
         if (WRITE_POL == `IOB_CACHE_WRITE_BACK) begin : g_write_back
            // dirty-memory
            always @(posedge clk_i, posedge reset_i) begin
               if (reset_i) begin
                  dirty_reg <= 0;
               end else if (write_req_o) begin
                  // updates postion with 0
                  dirty_reg <= dirty_reg & ~(1 << (index_reg));
               end else if (write_access & hit) begin
                  // updates position with 1 (needs to be index_reg otherwise updates the new index if the previous access was a write)
                  dirty_reg <= dirty_reg | (1 << (index_reg));
               end else begin
                  dirty_reg <= dirty_reg;
               end
            end

            always @(posedge clk_i) dirty <= dirty_reg[index];

            // flush line
            // flush if there is not a hit, and is dirty
            assign write_req_o = write_access & ~(way_hit) & dirty;
            assign write_addr_o = {
               line_tag, index
            };  // the position of the current block in cache (not of the access)
            assign write_wdata_o = line_rdata;
         end
      end
   endgenerate

endmodule

/*---------------------------------*/
/* Byte-width generable iob-sp-ram */
/*---------------------------------*/

// For cycle that generated byte-width (single enable) single-port SRAM
// older synthesis tool may require this approch

module iob_gen_sp_ram #(
   parameter DATA_W = 32,
   parameter ADDR_W = 10
) (
   input                 clk_i,
   input                 en_i,
   input  [DATA_W/8-1:0] we_i,
   input  [  ADDR_W-1:0] addr_i,
   output [  DATA_W-1:0] data_o,
   input  [  DATA_W-1:0] data_i
);

   genvar i;
   generate
      for (i = 0; i < (DATA_W / 8); i = i + 1) begin : g_ram
         iob_ram_sp #(
            .DATA_W(8),
            .ADDR_W(ADDR_W)
         ) iob_cache_mem (
            .clk_i (clk_i),
            .en_i  (en_i),
            .we_i  (we_i[i]),
            .addr_i(addr_i),
            .d_o   (data_o[8*i+:8]),
            .d_i   (data_i[8*i+:8])
         );
      end
   endgenerate

endmodule
