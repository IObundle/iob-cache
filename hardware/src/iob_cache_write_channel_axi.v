`timescale 1ns / 1ps

`include "iob_cache_conf.vh"
`include "iob_cache.vh"

module iob_cache_write_channel_axi
  #(
    parameter ADDR_W = `IOB_CACHE_ADDR_W,
    parameter DATA_W = `IOB_CACHE_DATA_W,
    parameter BE_ADDR_W = `IOB_CACHE_BE_ADDR_W,
    parameter BE_DATA_W = `IOB_CACHE_BE_DATA_W,
    parameter WRITE_POL  = `IOB_CACHE_WRITE_THROUGH,
    parameter WORD_OFFSET_W = `IOB_CACHE_WORD_OFFSET_W,
    parameter AXI_ID_W = `IOB_CACHE_AXI_ID_W,
    parameter AXI_LEN_W = `IOB_CACHE_AXI_LEN_W,
    parameter AXI_ADDR_W = BE_ADDR_W,
    parameter AXI_DATA_W = BE_DATA_W,
    parameter [AXI_ID_W-1:0] AXI_ID = `IOB_CACHE_AXI_ID
    )
   (
    input                                                              valid,
    input [ADDR_W-1 : `IOB_CACHE_NBYTES_W + WRITE_POL*WORD_OFFSET_W]             addr,
    input [DATA_W + WRITE_POL*(DATA_W*(2**WORD_OFFSET_W)-DATA_W)-1 :0] wdata,
    input [`IOB_CACHE_NBYTES-1:0]                                                wstrb,
    output reg                                                         ready,
`include "iob_axi_m_write_port.vh"
    input                                                              clk_i,
    input                                                              reset 
    );

   reg                                                                 axi_awvalid_int;
   reg                                                                 axi_wvalid_int;
   reg                                                                 axi_bready_int;

   assign axi_awvalid_o = axi_awvalid_int;
   assign axi_wvalid_o = axi_wvalid_int;
   assign axi_bready_o = axi_bready_int;

   genvar                                                                       i;
   generate
      if (WRITE_POL == `IOB_CACHE_WRITE_THROUGH) begin
         // Constant AXI signals
         assign axi_awid_o    = `IOB_CACHE_AXI_ID;
         assign axi_awlen_o   = 8'd0;

	 assign axi_awsize_o  = `IOB_CACHE_BE_NBYTES_W;    // verify - Writes data of the size of BE_DATA_W	 
	 assign axi_awburst_o = 2'd0;
         assign axi_awlock_o  = 1'b0; // 00 - Normal Access
         assign axi_awcache_o = 4'b0011;
         assign axi_awprot_o  = 3'd0;
         assign axi_awqos_o   = 4'd0;
         assign axi_wlast_o   = axi_wvalid_o;

         // AXI Buffer Output signals
         assign axi_awaddr_o = {BE_ADDR_W{1'b0}} + {addr[ADDR_W-1 : `IOB_CACHE_BE_NBYTES_W], {`IOB_CACHE_BE_NBYTES_W{1'b0}}};

         if (BE_DATA_W == DATA_W) begin
            assign axi_wstrb_o = wstrb;
            assign axi_wdata_o = wdata;
         end else begin
            wire [`IOB_CACHE_BE_NBYTES_W - `IOB_CACHE_NBYTES_W -1 :0] word_align = addr[`IOB_CACHE_NBYTES_W +: (`IOB_CACHE_BE_NBYTES_W - `IOB_CACHE_NBYTES_W)];
            assign axi_wstrb_o = wstrb << (word_align * `IOB_CACHE_NBYTES);

            for (i=0; i < BE_DATA_W/DATA_W; i=i+1) begin : wdata_block
               assign axi_wdata_o[(i+1)*DATA_W-1:i*DATA_W] = wdata;
            end
         end

         localparam
           idle    = 2'd0,
           address = 2'd1,
           write   = 2'd2,
           verif   = 2'd3;

         reg [1:0]                               state;

         always @(posedge clk_i, posedge reset) begin
            if (reset)
              state <= idle;
            else
              case (state)
                idle: begin
                   if (valid)
                     state <= address;
                   else
                     state <= idle;
                end
                address: begin
                   if (axi_awready_i)
                     state <= write;
                   else
                     state <= address;
                end
                write: begin
                   if (axi_wready_i)
                     state <= verif;
                   else
                     state <= write;
                end
                default: begin // verif - needs to be after the last word has been written, so this can't be optim
                   if (axi_bvalid_i & (axi_bresp_i == 2'b00) & ~valid)
                     state <= idle; // no more words to write
                   else
                     if (axi_bvalid_i & (axi_bresp_i == 2'b00) & valid)
                       state <= address; // buffer still isn't empty
                     else
                       if (axi_bvalid_i & ~(axi_bresp_i == 2'b00)) // error
                         state <= address; // goes back to transfer the same data.
                       else
                         state <= verif;
                end
              endcase
         end

         always @* begin
            ready       = 1'b0;
            axi_awvalid_int = 1'b0;
            axi_wvalid_int  = 1'b0;
            axi_bready_int  = 1'b0;

            case (state)
              idle:
                ready = 1'b1;
              address:
                axi_awvalid_int = 1'b1;
              write:
                axi_wvalid_int  = 1'b1;
              default: begin // verif
                 axi_bready_int = 1'b1;
                 ready      = axi_bvalid_i & ~(|axi_bresp_i);
              end
            endcase
         end
      end else begin // if (WRITE_POL == `IOB_CACHE_WRITE_BACK)
         if (`IOB_CACHE_LINE2BE_W > 0) begin
            // Constant AXI signals
            assign axi_awid_o    = `IOB_CACHE_AXI_ID;
            assign axi_awlock_o  = 1'b0;
            assign axi_awcache_o = 4'b0011;
            assign axi_awprot_o  = 3'd0;
            assign axi_awqos_o   = 4'd0;

            // Burst parameters
            assign axi_awlen_o   = 2**`IOB_CACHE_LINE2BE_W - 1; // will choose the burst lenght depending on the cache's and slave's data width
            assign axi_awsize_o  = `IOB_CACHE_BE_NBYTES_W;      // each word will be the width of the memory for maximum bandwidth
            assign axi_awburst_o = 2'b01;            // incremental burst

            // memory address
            assign axi_awaddr_o  = {BE_ADDR_W{1'b0}} + {addr, {(`IOB_CACHE_NBYTES_W+WORD_OFFSET_W){1'b0}}}; // base address for the burst, with width extension

            // memory write-data
            reg [`IOB_CACHE_LINE2BE_W-1:0] word_counter;
            assign axi_wdata_o = wdata >> (word_counter*BE_DATA_W);
            assign axi_wstrb_o = {`IOB_CACHE_BE_NBYTES{1'b1}};
            assign axi_wlast_o = &word_counter;

            localparam
              idle    = 2'd0,
              address = 2'd1,
              write   = 2'd2,
              verif   = 2'd3;

            reg [1:0]            state;

            always @(posedge clk_i, posedge reset) begin
               if (reset) begin
                  state <= idle;
                  word_counter <= 0;
               end else begin
                  word_counter <= 0;

                  case (state)
                    idle:
                      if (valid)
                        state <= address;
                      else
                        state <= idle;
                    address:
                      if (axi_awready_i)
                        state <= write;
                      else
                        state <= address;
                    write:
                      if (axi_wready_i & (&word_counter)) // last word written
                        state <= verif;
                      else
                        if (axi_wready_i & ~(&word_counter)) begin // word still available
                           state <= write;
                           word_counter <= word_counter+1;
                        end else begin // waiting for handshake
                           state <= write;
                           word_counter <= word_counter;
                        end
                    verif:
                      if (axi_bvalid_i & (axi_bresp_i == 2'b00))
                        state <= idle; // write transfer completed
                      else
                        if (axi_bvalid_i & ~(axi_bresp_i == 2'b00))
                          state <= address; // error, requires re-transfer
                        else
                          state <= verif; // still waiting for response
                    default:;
                  endcase
               end
            end

            always @* begin
               ready       = 1'b0;
               axi_awvalid_int = 1'b0;
               axi_wvalid_int  = 1'b0;
               axi_bready_int  = 1'b0;

               case (state)
                 idle:
                   ready = ~valid;
                 address:
                   axi_awvalid_int = 1'b1;
                 write:
                   axi_wvalid_int  = 1'b1;
                 default: begin // verif
                    axi_bready_int = 1'b1;
                    ready      = axi_bvalid_i & ~(|axi_bresp_i);
                 end
               endcase
            end
         end else  begin
            // Constant AXI signals
            assign axi_awid_o    = `IOB_CACHE_AXI_ID;
            assign axi_awlock_o  = 1'b0;
            assign axi_awcache_o = 4'b0011;
            assign axi_awprot_o  = 3'd0;
            assign axi_awqos_o   = 4'd0;

            // Burst parameters - single
            assign axi_awlen_o   = 8'd0;        // A single burst of Memory data width word
            assign axi_awsize_o  = `IOB_CACHE_BE_NBYTES_W; // each word will be the width of the memory for maximum bandwidth
            assign axi_awburst_o = 2'b00;

            // memory address
            assign axi_awaddr_o  = {BE_ADDR_W{1'b0}} + {addr, {`IOB_CACHE_BE_NBYTES_W{1'b0}}}; // base address for the burst, with width extension

            // memory write-data
            assign axi_wdata_o = wdata;
            assign axi_wstrb_o = {`IOB_CACHE_BE_NBYTES{1'b1}}; // uses entire bandwidth
            assign axi_wlast_o = axi_wvalid_o;

            localparam
              idle    = 2'd0,
              address = 2'd1,
              write   = 2'd2,
              verif   = 2'd3;

            reg [1:0]                           state;

            always @(posedge clk_i, posedge reset) begin
               if (reset)
                 state <= idle;
               else
                 case (state)
                   idle:
                     if (valid)
                       state <= address;
                     else
                       state <= idle;
                   address:
                     if (axi_awready_i)
                       state <= write;
                     else
                       state <= address;
                   write:
                     if (axi_wready_i)
                       state <= verif;
                     else
                       state <= write;
                     default: // verif
                       if (axi_bvalid_i & (axi_bresp_i == 2'b00))
                         state <= idle; // write transfer completed
                       else
                         if (axi_bvalid_i & ~(axi_bresp_i == 2'b00))
                           state <= address; // error, requires re-transfer
                         else
                           state <= verif; // still waiting for response
                 endcase
            end

            always @* begin
               ready       = 1'b0;
               axi_awvalid_int = 1'b0;
               axi_wvalid_int  = 1'b0;
               axi_bready_int  = 1'b0;

               case (state)
                 idle:
                   ready = ~valid;
                 address:
                   axi_awvalid_int = 1'b1;
                 write:
                   axi_wvalid_int  = 1'b1;
                 default: begin // verif
                    axi_bready_int = 1'b1;
                    ready      = axi_bvalid_i & ~(|axi_bresp_i);
                 end
               endcase
            end
         end
      end
   endgenerate

endmodule
