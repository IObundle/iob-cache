`timescale 1ns / 1ps
`include "iob-cache.vh"

module read_channel_axi
  #(
    parameter FE_ADDR_W   = 32,
    parameter FE_DATA_W   = 32,
    parameter FE_NBYTES  = FE_DATA_W/8,
    parameter WORD_OFF_W = 3,
    //Higher hierarchy memory (slave) interface parameters 
    parameter BE_ADDR_W = FE_ADDR_W, //Address width of the higher hierarchy memory
    parameter BE_DATA_W = FE_DATA_W, //Data width of the memory 
    parameter BE_NBYTES = BE_DATA_W/8, //Number of bytes
    parameter BE_BYTE_W = $clog2(BE_NBYTES), //Offset of the Number of Bytes
    //Cache-Memory base Offset
    parameter LINE2MEM_W = WORD_OFF_W-$clog2(BE_DATA_W/FE_DATA_W), //burst offset based on the cache word's and memory word size
    // //AXI specific parameters
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0  //AXI ID value
    )
   (
    input                                        clk,
    input                                        reset,
    input                                        replace_valid,
    input [FE_ADDR_W -1: BE_BYTE_W + LINE2MEM_W] replace_addr,
    output reg                                   replace,
    output                                       read_valid,
    output reg [LINE2MEM_W-1:0]                  read_addr,
    output [BE_DATA_W-1:0]                       read_rdata,
    //Address Read
    output reg                                   axi_arvalid, 
    output [BE_ADDR_W-1:0]                       axi_araddr, 
    output [7:0]                                 axi_arlen,
    output [2:0]                                 axi_arsize,
    output [1:0]                                 axi_arburst,
    output [0:0]                                 axi_arlock,
    output [3:0]                                 axi_arcache,
    output [2:0]                                 axi_arprot,
    output [3:0]                                 axi_arqos,
    output [AXI_ID_W-1:0]                        axi_arid,
    input                                        axi_arready,
    //Read
    input                                        axi_rvalid, 
    input [BE_DATA_W-1:0]                        axi_rdata,
    input [1:0]                                  axi_rresp,
    input                                        axi_rlast, 
    output reg                                   axi_rready
    );

   generate
      if(LINE2MEM_W > 0)
        begin
           
           //Constant AXI signals
           assign axi_arid    = AXI_ID;
           assign axi_arlock  = 1'b0;
           assign axi_arcache = 4'b0011;
           assign axi_arprot  = 3'd0;
           assign axi_arqos   = 4'd0;
           //Burst parameters
           assign axi_arlen   = 2**LINE2MEM_W -1; //will choose the burst lenght depending on the cache's and slave's data width
           assign axi_arsize  = BE_BYTE_W; //each word will be the width of the memory for maximum bandwidth
           assign axi_arburst = 2'b01; //incremental burst
           assign axi_araddr  = {BE_ADDR_W{1'b0}} + {replace_addr, {(LINE2MEM_W+BE_BYTE_W){1'b0}}}; //base address for the burst, with width extension 

           
           // Read Line values
           assign read_rdata = axi_rdata;
           assign read_valid = axi_rvalid;
           
           
           localparam
             idle          = 2'd0,
             init_process  = 2'd1,
             load_process  = 2'd2,
             end_process   = 2'd3;
           
           
           reg [1:0]                           state;
           reg                                 slave_error;//axi slave_error during reply (axi_rresp[1] == 1) - burst can't be interrupted, so a flag needs to be active
           
           
           always @(posedge clk, posedge reset)
             begin
                if(reset)
                  begin
                     state <= idle;
                     read_addr <= 0;
                     slave_error <= 0;
                  end
                else
                  begin
                     slave_error <= slave_error;
                     case (state)   
                       idle:
                         begin
                            slave_error <= 0;
                            read_addr <= 0;  
                            if(replace_valid)
                              state <= init_process;
                            else
                              state <= idle;
                         end

                       init_process:
                         begin
                            slave_error <= 0;
                            read_addr <= 0;  
                            if(axi_arready)
                              state <= load_process;
                            else
                              state <= init_process;
                         end

                       load_process:
                         begin
                            if(axi_rvalid)
                              if(axi_rlast)
                                begin
                                   state <= end_process;
                                   read_addr <= read_addr; //to avoid writting last data in first line word
                                   if(axi_rresp != 2'b00) //slave_error - received at the same time as the valid - needs to wait until the end to start all over - going directly to init_process would cause a stall to this burst
                                     slave_error <= 1;
                                end
                              else
                                begin
                                   read_addr <= read_addr +1;
                                   state <= load_process;
                                   if(axi_rresp != 2'b00) //slave_error - received at the same time as the valid - needs to wait until the end to start all over - going directly to init_process would cause a stall to this burst
                                     slave_error <= 1;
                                end
                            else
                              begin
                                 read_addr <= read_addr;
                                 state <= load_process;
                              end
                         end

                       end_process://delay for the read_latency of the memories (if the rdata is the last word)
                         if (slave_error)
                           state <= init_process;
                         else
                           state <= idle;
                       
                       default:;
                     endcase
                  end
             end
           
           always @*
             begin
                axi_arvalid   = 1'b0;
                axi_rready    = 1'b0;
                replace = 1'b1;
                case(state)

                  idle:
                    replace = 1'b0;
                  
                  init_process:
                    axi_arvalid = 1'b1;

                  load_process:
                    axi_rready  = 1'b1;
                  
                  default:;
                  
                endcase
             end // always @ *
        end // if (LINE2MEM_W > 0)

      
      else
         
        begin
           //Constant AXI signals
           assign axi_arid    = AXI_ID;
           assign axi_arlock  = 1'b0;
           assign axi_arcache = 4'b0011;
           assign axi_arprot  = 3'd0;
           assign axi_arqos   = 4'd0;
           //Burst parameters - single 
           assign axi_arlen   = 8'd0; //A single burst of Memory data width word
           assign axi_arsize  = BE_BYTE_W; //each word will be the width of the memory for maximum bandwidth
           assign axi_arburst = 2'b00; 
           assign axi_araddr  = {BE_ADDR_W{1'b0}} + {replace_addr, {BE_BYTE_W{1'b0}}}; //base address for the burst, with width extension 

           // Read Line values
           assign read_valid = axi_rvalid;
           assign read_rdata  = axi_rdata;
           
           
           localparam
             idle          = 2'd0,
             init_process  = 2'd1,
             load_process  = 2'd2,
             end_process   = 2'd3;
           
           
           reg [1:0]                           state;

           
           always @(posedge clk, posedge reset)
             begin
                if(reset)
                   
                  state <= idle;
                
                else
                   
                  case (state)   
                    idle:
                      begin
                         if(replace_valid)
                           state <= init_process;
                         else
                           state <= idle;
                      end

                    init_process:
                      begin                      
                         if(axi_arready)
                           state <= load_process;
                         else
                           state <= init_process;
                      end

                    load_process:
                      begin
                         if(axi_rvalid)
                           if(axi_rresp != 2'b00) //slave_error - received at the same time as valid
                             state <= init_process;
                           else
                             state <= end_process;
                         else
                           state <= load_process;
                      end

                    end_process://delay for the read_latency of the memories (if the rdata is the last word)
                      state <= idle;
                    
                    
                    default:;
                  endcase
             end
           
           
           always @*
             begin
                axi_arvalid   = 1'b0;
                axi_rready    = 1'b0;
                replace = 1'b1;
                case(state)

                  idle:
                    begin
                       replace = 1'b0;
                    end
                  
                  init_process:
                    begin
                       axi_arvalid = 1'b1;
                    end

                  load_process:
                    begin
                       axi_rready  = 1'b1;             
                    end
                  
                  default:;
                  
                endcase
             end // always @ *
           
        end     
   endgenerate 
   
endmodule // read_process_native
