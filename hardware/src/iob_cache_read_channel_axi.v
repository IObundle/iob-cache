`timescale 1ns / 1ps

`include "iob_cache_swreg_def.vh"
`include "iob_cache_conf.vh"

module iob_cache_read_channel_axi #(
   parameter                ADDR_W        = `IOB_CACHE_ADDR_W,
   parameter                DATA_W        = `IOB_CACHE_DATA_W,
   parameter                BE_ADDR_W     = `IOB_CACHE_BE_ADDR_W,
   parameter                BE_DATA_W     = `IOB_CACHE_BE_DATA_W,
   parameter                WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
   parameter                AXI_ID_W      = `IOB_CACHE_AXI_ID_W,
   parameter [AXI_ID_W-1:0] AXI_ID        = `IOB_CACHE_AXI_ID,
   parameter                AXI_LEN_W     = `IOB_CACHE_AXI_LEN_W,
   parameter                AXI_ADDR_W    = BE_ADDR_W,
   parameter                AXI_DATA_W    = BE_DATA_W,
   //derived parameters
   parameter                BE_NBYTES     = BE_DATA_W / 8,
   parameter                BE_NBYTES_W   = $clog2(BE_NBYTES),
   parameter                LINE2BE_W     = WORD_OFFSET_W - $clog2(BE_DATA_W / DATA_W)
) (
   input                                       replace_valid_i,
   input      [ADDR_W-1:BE_NBYTES_W+LINE2BE_W] replace_addr_i,
   output reg                                  replace_o,
   output                                      read_valid_o,
   output reg [                 LINE2BE_W-1:0] read_addr_o,
   output     [                 BE_DATA_W-1:0] read_rdata_o,
   `include "axi_m_read_port.vs"
   input                                       clk_i,
   input                                       reset_i
);

   reg axi_arvalid_int;
   reg axi_rready_int;

   assign axi_arvalid_o = axi_arvalid_int;
   assign axi_rready_o  = axi_rready_int;


   generate
      if (LINE2BE_W > 0) begin : g_line2be_w
         // Constant AXI signals
         assign axi_arid_o = AXI_ID;
         assign axi_arlock_o = 1'b0;
         assign axi_arcache_o = 4'b0011;
         assign axi_arprot_o = 3'd0;
         assign axi_arqos_o = 4'd0;

         // Burst parameters
         assign axi_arlen_o   = 2**LINE2BE_W - 1'b1; // will choose the burst lenght depending on the cache's and slave's data width
         assign axi_arsize_o  = BE_NBYTES_W;         // each word will be the width of the memory for maximum bandwidth
         assign axi_arburst_o = 2'b01;  // incremental burst
         assign axi_araddr_o  = {BE_ADDR_W{1'b0}} + {replace_addr_i, {(LINE2BE_W+BE_NBYTES_W){1'b0}}}; // base address for the burst, with width extension

         // Read Line values
         assign read_rdata_o = axi_rdata_i;
         assign read_valid_o = axi_rvalid_i;

         localparam idle = 2'd0, init_process = 2'd1, load_process = 2'd2, end_process = 2'd3;

         reg [1:0] state;
         reg                                 slave_error; // axi slave_error during reply (axi_rresp[1] == 1) - burst can't be interrupted, so a flag needs to be active

         always @(posedge clk_i, posedge reset_i) begin
            if (reset_i) begin
               state       <= idle;
               read_addr_o   <= 0;
               slave_error <= 0;
            end else begin
               slave_error <= slave_error;

               case (state)
                  idle: begin
                     slave_error <= 0;
                     read_addr_o   <= 0;
                     if (replace_valid_i) state <= init_process;
                     else state <= idle;
                  end
                  init_process: begin
                     slave_error <= 0;
                     read_addr_o   <= 0;
                     if (axi_arready_i) state <= load_process;
                     else state <= init_process;
                  end
                  load_process: begin
                     if (axi_rvalid_i)
                        if (axi_rlast_i) begin
                           state     <= end_process;
                           // to avoid writting last data in first line word
                           read_addr_o <= read_addr_o;
                           // slave_error - received at the same time as the valid - needs to wait until the end to start all over - going directly to init_process would cause a stall to this burst
                           if (axi_rresp_i != 2'b00) slave_error <= 1;
                        end else begin
                           read_addr_o <= read_addr_o + 1'b1;
                           state     <= load_process;
                           // slave_error - received at the same time as the valid - needs to wait until the end to start all over - going directly to init_process would cause a stall to this burst
                           if (axi_rresp_i != 2'b00) slave_error <= 1;
                        end
                     else begin
                        read_addr_o <= read_addr_o;
                        state     <= load_process;
                     end
                  end
                  // end_process - delay for the read_latency of the memories (if the rdata is the last word)
                  default: begin
                     if (slave_error) state <= init_process;
                     else state <= idle;
                  end
               endcase
            end
         end

         always @* begin
            axi_arvalid_int = 1'b0;
            axi_rready_int  = 1'b0;
            replace_o         = 1'b1;

            case (state)
               idle:         replace_o = 1'b0;
               init_process: axi_arvalid_int = 1'b1;
               default:      axi_rready_int = 1'b1;  // load_process
            endcase
         end

      end else begin : g_no_line2be_w
         // Constant AXI signals
         assign axi_arid_o = AXI_ID;
         assign axi_arlock_o = 1'b0;
         assign axi_arcache_o = 4'b0011;
         assign axi_arprot_o = 3'd0;
         assign axi_arqos_o = 4'd0;

         // Burst parameters - single
         assign axi_arlen_o = 8'd0;  // A single burst of Memory data width word
         assign axi_arsize_o  = BE_NBYTES_W; // each word will be the width of the memory for maximum bandwidth
         assign axi_arburst_o = 2'b00;
         assign axi_araddr_o  = {BE_ADDR_W{1'b0}} + {replace_addr_i, {BE_NBYTES_W{1'b0}}}; // base address for the burst, with width extension

         // Read Line values
         assign read_valid_o = axi_rvalid_i;
         assign read_rdata_o = axi_rdata_i;

         localparam idle = 2'd0, init_process = 2'd1, load_process = 2'd2, end_process = 2'd3;

         reg [1:0] state;

         always @(posedge clk_i, posedge reset_i) begin
            if (reset_i) state <= idle;
            else
               case (state)
                  idle: begin
                     if (replace_valid_i) state <= init_process;
                     else state <= idle;
                  end
                  init_process: begin
                     if (axi_arready_i) state <= load_process;
                     else state <= init_process;
                  end
                  load_process: begin
                     if (axi_rvalid_i)
                        if (axi_rresp_i != 2'b00)  // slave_error - received at the same time as valid
                           state <= init_process;
                        else state <= end_process;
                     else state <= load_process;
                  end
                  end_process:
                  state <= idle; // delay for the read_latency of the memories (if the rdata is the last word)
                  default: ;
               endcase
         end

         always @* begin
            axi_arvalid_int = 1'b0;
            axi_rready_int  = 1'b0;
            replace_o         = 1'b1;

            case (state)
               idle: begin
                  replace_o = 1'b0;
               end
               init_process: begin
                  axi_arvalid_int = 1'b1;
               end
               load_process: begin
                  axi_rready_int = 1'b1;
               end
               default: ;
            endcase
         end
      end
   endgenerate

endmodule
