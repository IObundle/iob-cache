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
    parameter [AXI_ID_W-1:0] AXI_ID = 0
    ) 
   (
    input                         clk,
    input                         reset,

    input                         valid,
    input [FE_ADDR_W-1:FE_BYTE_W] addr,
    input [FE_NBYTES-1:0]         wstrb,
    input [FE_DATA_W-1:0]         wdata,
    output reg                    ready,
    // Address Write
    output reg                    axi_awvalid,
    output [BE_ADDR_W-1:0]        axi_awaddr,
    output [7:0]                  axi_awlen,
    output [2:0]                  axi_awsize,
    output [1:0]                  axi_awburst,
    output [0:0]                  axi_awlock,
    output [3:0]                  axi_awcache,
    output [2:0]                  axi_awprot,
    output [3:0]                  axi_awqos,
    output [AXI_ID_W-1:0]         axi_awid, 
    input                         axi_awready,
    //Write
    output reg                    axi_wvalid, 
    output [BE_DATA_W-1:0]        axi_wdata,
    output [BE_NBYTES-1:0]        axi_wstrb,
    output                        axi_wlast,
    input                         axi_wready,
    input                         axi_bvalid,
    input [1:0]                   axi_bresp,
    output reg                    axi_bready
    );


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


   
   generate
      if(BE_DATA_W == FE_DATA_W)
        begin
           assign axi_wstrb = wstrb;
           assign axi_wdata = wdata;
           
        end
      else
        begin
           wire [BE_BYTE_W - FE_BYTE_W -1 :0] word_align = addr[FE_BYTE_W +: (BE_BYTE_W - FE_BYTE_W)];
           assign axi_wstrb = wstrb << (word_align * FE_NBYTES);
           assign axi_wdata = wdata << (word_align * FE_DATA_W);
        end
   endgenerate
   
   
   localparam
     idle           = 2'd0,
     addr_process   = 2'd1,
     write_process  = 2'd2,
     verif_process  = 2'd3;  
   
   reg [1:0]                                  state;

   
   always @(posedge clk, posedge reset)
     begin
        if(reset)
          state <= idle;
        else
          case(state)

            idle:
              begin
                 if(valid)
                   state <= addr_process;
              end
            
            addr_process:
              begin
                 if(axi_awready)
                   state <= write_process;
                 
                 else
                   state <= addr_process;
              end

            write_process:
              begin
                 if (axi_wready)
                   state <= verif_process;
                 else
                   state <= write_process;
              end

            verif_process: //needs to be after the last word has been written, so this can't be optim
              begin
                 if(axi_bvalid)
                   if(axi_bresp == 2'b00)//00 or 01 - OKAY - needs to be after the last word has been written, so this can't be optimized by removing this state
                     state <= idle;
                   else
                     state <= addr_process; //goes back to transfer the same data.
                 else
                   state <= verif_process;
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
          addr_process:
            axi_awvalid = 1'b1;
          write_process:
            axi_wvalid  = 1'b1;
          verif_process:
            axi_bready  = 1'b1;
          default:;
        endcase
     end       

   
endmodule






