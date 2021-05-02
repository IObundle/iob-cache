`timescale 1ns / 1ps
`include "iob-cache.vh"

module write_channel_axi 
  #(
    parameter FE_ADDR_W = 32,
    parameter FE_DATA_W = 32,
    parameter FE_NBYTES = FE_DATA_W/8,
    parameter FE_BYTE_W = $clog2(FE_NBYTES), 
    parameter BE_ADDR_W = FE_ADDR_W, 
    parameter BE_DATA_W = FE_DATA_W,
    parameter BE_NBYTES = BE_DATA_W/8, 
    parameter BE_BYTE_W = $clog2(BE_NBYTES),
    parameter AXI_ID_W  = 1,
    parameter [AXI_ID_W-1:0] AXI_ID = 0,
    // Write-Policy
    parameter WRITE_POL  = `WRITE_THROUGH, //write policy: write-through (0), write-back (1)
    parameter WORD_OFF_W = 3, //required for write-back
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W)  //burst offset based on the cache and memory word size
    ) 
   (
    input                                                                    clk,
    input                                                                    reset,

    input                                                                    valid,
    input [FE_ADDR_W-1:FE_BYTE_W + WRITE_POL*WORD_OFF_W]                     addr,
    input [FE_DATA_W + WRITE_POL*(FE_DATA_W*(2**WORD_OFF_W)-FE_DATA_W)-1 :0] wdata,
    input [FE_NBYTES-1:0]                                                    wstrb,
    output reg                                                               ready,
    // Address Write
    output reg                                                               axi_awvalid,
    output [BE_ADDR_W-1:0]                                                   axi_awaddr,
    output [7:0]                                                             axi_awlen,
    output [2:0]                                                             axi_awsize,
    output [1:0]                                                             axi_awburst,
    output [0:0]                                                             axi_awlock,
    output [3:0]                                                             axi_awcache,
    output [2:0]                                                             axi_awprot,
    output [3:0]                                                             axi_awqos,
    output [AXI_ID_W-1:0]                                                    axi_awid, 
    input                                                                    axi_awready,
    //Write
    output reg                                                               axi_wvalid, 
    output [BE_DATA_W-1:0]                                                   axi_wdata,
    output [BE_NBYTES-1:0]                                                   axi_wstrb,
    output                                                                   axi_wlast,
    input                                                                    axi_wready,
    input                                                                    axi_bvalid,
    input [1:0]                                                              axi_bresp,
    output reg                                                               axi_bready
    );
   
   genvar                                                                       i;
   generate
      if(WRITE_POL == `WRITE_THROUGH) begin
         
         //Constant AXI signals
         assign axi_awid    = AXI_ID;
         assign axi_awlen   = 8'd0;
         assign axi_awsize  = BE_BYTE_W; // verify - Writes data of the size of BE_DATA_W
         assign axi_awburst = 2'd0;
         assign axi_awlock  = 1'b0; // 00 - Normal Access
         assign axi_awcache = 4'b0011;
         assign axi_awprot  = 3'd0;
         assign axi_awqos   = 4'd0;
         assign axi_wlast   = axi_wvalid;
         
         //AXI Buffer Output signals
         assign axi_awaddr = {BE_ADDR_W{1'b0}} + {addr[FE_ADDR_W-1:BE_BYTE_W], {BE_BYTE_W{1'b0}}};
         
         
         if(BE_DATA_W == FE_DATA_W)
           begin
              assign axi_wstrb = wstrb;
              assign axi_wdata = wdata;
              
           end
         else
           begin
              wire [BE_BYTE_W - FE_BYTE_W -1 :0] word_align = addr[FE_BYTE_W +: (BE_BYTE_W - FE_BYTE_W)];
              assign axi_wstrb = wstrb << (word_align * FE_NBYTES);
              
              for (i = 0; i < BE_DATA_W/FE_DATA_W; i = i +1)
                assign axi_wdata[(i+1)*FE_DATA_W-1:i*FE_DATA_W] = wdata;
           end
         
         
         localparam
           idle    = 2'd0,
           address = 2'd1,
           write   = 2'd2,
           verif   = 2'd3;  

         reg [1:0]                               state;

         
         always @(posedge clk, posedge reset)
           begin
              if(reset)
                state <= idle;
              else
                case(state)

                  idle: begin
                    if(valid)
                      state <= address;
                    else
                      state <= idle;
                  end
                  
                  address: begin
                    if(axi_awready)
                      state <= write;
                    else
                      state <= address;
                  end
                  
                  write: begin
                    if (axi_wready)
                      state <= verif;
                    else
                      state <= write;
                  end
                  
                  verif: begin //needs to be after the last word has been written, so this can't be optim
                     if(axi_bvalid & (axi_bresp == 2'b00) & ~valid)
                       state <= idle; //no more words to write
                     else
                       if(axi_bvalid & (axi_bresp == 2'b00) & valid)
                         state <= address; //buffer still isn't empty
                       else
                         if (axi_bvalid & ~(axi_bresp == 2'b00))//error
                           state <= address; //goes back to transfer the same data.
                         else
                           state <= verif;
                  end

                  default: ;         

                endcase 
           end // always @ (posedge clk, posedge reset)
         
         
         always @*
           begin
              ready       = 1'b0;
              axi_awvalid = 1'b0;
              axi_wvalid  = 1'b0;
              axi_bready  = 1'b0;      
              case(state)
                idle:
                  ready = 1'b1;
                address:
                  axi_awvalid = 1'b1;
                write:
                  axi_wvalid  = 1'b1;
                verif:
                  begin
                     axi_bready = 1'b1;
                     ready      = axi_bvalid & ~(|axi_bresp);
                  end
                default:;
              endcase
           end       
         

      end 
      else begin // if (WRITE_POL == `WRITE_BACK)

         if(LINE2MEM_W > 0) begin
            
            //Constant AXI signals
            assign axi_awid    = AXI_ID;
            assign axi_awlock  = 1'b0;
            assign axi_awcache = 4'b0011;
            assign axi_awprot  = 3'd0;
            assign axi_awqos   = 4'd0;
            
            //Burst parameters
            assign axi_awlen   = 2**LINE2MEM_W -1; //will choose the burst lenght depending on the cache's and slave's data width
            assign axi_awsize  = BE_BYTE_W; //each word will be the width of the memory for maximum bandwidth
            assign axi_awburst = 2'b01; //incremental burst
            
            //memory address
            assign axi_awaddr  = {BE_ADDR_W{1'b0}} + {addr, {(FE_BYTE_W+WORD_OFF_W){1'b0}}}; //base address for the burst, with width extension 
            
            // memory write-data
            reg [LINE2MEM_W-1:0] word_counter;
            assign axi_wdata = wdata >> (word_counter*BE_DATA_W);
            assign axi_wstrb = {BE_NBYTES{1'b1}};
            assign axi_wlast = &word_counter;
            
            
            localparam
              idle    = 2'd0,
              address = 2'd1,
              write   = 2'd2,
              verif   = 2'd3;

            reg [1:0]            state;
            
            always @(posedge clk, posedge reset)
              begin
                 if(reset) begin
                    state <= idle;
                    word_counter <= 0;
                 end
                 else begin
                    word_counter <= 0;
                    case(state)
                      
                      idle:
                        if(valid)
                          state <= address;
                        else
                          state <= idle;

                      address:
                        if(axi_awready)
                          state <= write;
                        else
                          state <= address;

                      write:
                        if(axi_wready & (&word_counter)) //last word written
                          state <= verif;
                        else
                          if(axi_wready & ~(&word_counter)) begin//word still available
                             state <= write;
                             word_counter <= word_counter+1;
                          end
                          else begin //waiting for handshake
                             state <= write;
                             word_counter <= word_counter;
                          end

                      verif:
                        if(axi_bvalid & (axi_bresp == 2'b00))
                          state <= idle; // write transfer completed
                        else
                          if (axi_bvalid & ~(axi_bresp == 2'b00))
                            state <= address; // error, requires re-transfer 
                          else
                            state <= verif; //still waiting for response
                      
                      default:;
                    endcase
                 end // else: !if(reset)
              end // always @ (posedge clk, posedge reset)

            always @*
              begin
                 ready       = 1'b0;
                 axi_awvalid = 1'b0;
                 axi_wvalid  = 1'b0;
                 axi_bready  = 1'b0;
                 
                 case(state)
                   idle:
                     ready = ~valid;
                   
                   address:
                     axi_awvalid = 1'b1;
                   
                   write:
                     axi_wvalid  = 1'b1;
                   
                   verif:
                     begin
                        axi_bready = 1'b1;
                        ready      = axi_bvalid & ~(|axi_bresp);
                     end
                   
                   default:;
                 endcase
              end // always @ *
            
         end // if (LINE2MEM_W > 0)      
         else  begin // if (LINE2MEM_W == 0)
            
            //Constant AXI signals
            assign axi_awid    = AXI_ID;
            assign axi_awlock  = 1'b0;
            assign axi_awcache = 4'b0011;
            assign axi_awprot  = 3'd0;
            assign axi_awqos   = 4'd0;
            
            //Burst parameters - single 
            assign axi_awlen   = 8'd0; //A single burst of Memory data width word
            assign axi_awsize  = BE_BYTE_W; //each word will be the width of the memory for maximum bandwidth
            assign axi_awburst = 2'b00; 
            
            //memory address
            assign axi_awaddr  = {BE_ADDR_W{1'b0}} + {addr, {BE_BYTE_W{1'b0}}}; //base address for the burst, with width extension 
            
            //memory write-data
            assign axi_wdata = wdata;
            assign axi_wstrb = {BE_NBYTES{1'b1}}; //uses entire bandwidth
            assign axi_wlast = axi_wvalid;
            
            localparam
              idle    = 2'd0,
              address = 2'd1,
              write   = 2'd2,
              verif   = 2'd3;
            
            reg [1:0]                           state;
            
            always @(posedge clk, posedge reset)
              begin
                 if(reset)
                   state <= idle;
                 else
                   case (state)
                     
                     idle:
                       if(valid)
                         state <= address;
                       else
                         state <= idle;
                     
                     address:
                       if(axi_awready)
                         state <= write;
                       else
                         state <= address;
                     
                     write:
                       if (axi_wready)
                         state <= verif;
                       else
                         state <= write;

                     verif:
                       if(axi_bvalid & (axi_bresp == 2'b00))
                         state <= idle; // write transfer completed
                       else
                         if (axi_bvalid & ~(axi_bresp == 2'b00))
                           state <= address; // error, requires re-transfer 
                         else
                           state <= verif; //still waiting for response
                     
                     default:;
                   endcase
              end
            
            
            always @*
              begin
                 ready       = 1'b0;
                 axi_awvalid = 1'b0;
                 axi_wvalid  = 1'b0;
                 axi_bready  = 1'b0; 
                 
                 case(state)
                   idle:
                     ready = ~valid;
                   
                   address:
                     axi_awvalid = 1'b1;
                   
                   write:
                        axi_wvalid  = 1'b1;
                   
                   verif:
                     begin
                        axi_bready = 1'b1;
                        ready      = axi_bvalid & ~(|axi_bresp);
                     end
                   
                   default:;
                 endcase
              end // always @ *
            
         end // else: !if(LINE2MEM_W > 0)          
      end // else: !if(WRITE_POL == `WRITE_THROUGH)
   endgenerate
   
endmodule
