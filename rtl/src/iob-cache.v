`timescale 1ns / 1ps
`include "iob-cache.vh"

///////////////
// IOb-cache //
///////////////

module iob_cache 
  #(
    //memory cache's parameters
    parameter ADDR_W   = 32,       //Address width - width that will used for the cache 
    parameter DATA_W   = 32,       //Data width - word size used for the cache
    parameter N_WAYS   = 4,        //Number of Cache Ways (Needs to be Potency of 2: 1, 2, 4, 8, ..)
    parameter LINE_OFF_W  = 6,     //Line-Offset Width - 2**NLINE_W total cache lines
    parameter WORD_OFF_W = 3,      //Word-Offset Width - 2**OFFSET_W total DATA_W words per line - WARNING about MEM_OFFSET_W (can cause word_counter [-1:0]
    parameter WTBUF_DEPTH_W = 4,   //Depth Width of Write-Through Buffer
    //Do NOT change - memory cache's parameters - dependency
    parameter NWAY_W   = $clog2(N_WAYS), //Cache Ways Width
    parameter N_BYTES  = DATA_W/8,       //Number of Bytes per Word
    parameter BYTES_W = $clog2(N_BYTES), //Offset of the Number of Bytes per Word
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 
    parameter MEM_NATIVE = 0,      //Cache's higher level memory interface: AXI(0-default), Native(1)
    parameter MEM_ADDR_W = ADDR_W, //Address width of the higher hierarchy memory
    parameter MEM_DATA_W = DATA_W, //Data width of the memory 
    parameter MEM_NBYTES = MEM_DATA_W/8, //Number of bytes
    parameter MEM_BYTES_W = $clog2(MEM_NBYTES), //Offset of Number of Bytes
    //AXI specific parameters
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0, //AXI ID value
    //Cache-Memory base Offset
    parameter MEM_OFFSET_W = WORD_OFF_W-$clog2(MEM_DATA_W/DATA_W), //burst offset based on the cache word's and memory word size (Can't be 0)
    //Look-ahead Interface - Store Front-End input signals
    parameter LA_INTERF = 0,
    /*---------------------------------------------------*/
    //Controller's options
    parameter CTRL_CNT_ID = 0, //Counters for both Data and Instruction Hits and Misses
    parameter CTRL_CNT = 1    //Counters for Cache Hits and Misses - Disabling this and previous, the Controller only store the buffer states and allows cache invalidations
    ) 
   (
    input                                    clk,
    input                                    reset,
    input [ADDR_W:$clog2(N_BYTES)]           addr, // cache_addr[ADDR_W] (MSB) selects cache (0) or controller (1)
    input [DATA_W-1:0]                       wdata,
    input [N_BYTES-1:0]                      wstrb,
    output [DATA_W-1:0]                      rdata,
    input                                    valid,
    output                                   ready,
    input                                    instr,
    // AXI interface 
    // Address Write
    output [AXI_ID_W-1:0]                    axi_awid, 
    output [MEM_ADDR_W-1:0]                  axi_awaddr,
    output [7:0]                             axi_awlen,
    output [2:0]                             axi_awsize,
    output [1:0]                             axi_awburst,
    output [0:0]                             axi_awlock,
    output [3:0]                             axi_awcache,
    output [2:0]                             axi_awprot,
    output [3:0]                             axi_awqos,
    output                                   axi_awvalid,
    input                                    axi_awready,
    //Write
    output [MEM_DATA_W-1:0]                  axi_wdata,
    output [MEM_NBYTES-1:0]                  axi_wstrb,
    output                                   axi_wlast,
    output                                   axi_wvalid, 
    input                                    axi_wready,
    input [AXI_ID_W-1:0]                     axi_bid,
    input [1:0]                              axi_bresp,
    input                                    axi_bvalid,
    output                                   axi_bready,
    //Address Read
    output [AXI_ID_W-1:0]                    axi_arid,
    output [MEM_ADDR_W-1:0]                  axi_araddr, 
    output [7:0]                             axi_arlen,
    output [2:0]                             axi_arsize,
    output [1:0]                             axi_arburst,
    output [0:0]                             axi_arlock,
    output [3:0]                             axi_arcache,
    output [2:0]                             axi_arprot,
    output [3:0]                             axi_arqos,
    output                                   axi_arvalid, 
    input                                    axi_arready,
    //Read
    input [AXI_ID_W-1:0]                     axi_rid,
    input [MEM_DATA_W-1:0]                   axi_rdata,
    input [1:0]                              axi_rresp,
    input                                    axi_rlast, 
    input                                    axi_rvalid, 
    output                                   axi_rready,
    //Native interface
    output [MEM_ADDR_W-1:$clog2(MEM_NBYTES)] mem_addr,
    output                                   mem_valid,
    input                                    mem_ready,
    output [MEM_DATA_W-1:0]                  mem_wdata,
    output [MEM_NBYTES-1:0]                  mem_wstrb,
    input [MEM_DATA_W-1:0]                   mem_rdata
    );
   
   //Internal signals
   wire [ADDR_W   : $clog2(N_BYTES)]         addr_int;
   wire                                      valid_int;
   wire [DATA_W-1 : 0]                       wdata_int;
   wire [N_BYTES-1: 0]                       wstrb_int;
   wire                                      instr_int; //Ctrl's counter
   wire                                      ready_int;
   assign ready = ready_int;
   
   
   wire                                      cache_select = ~addr_int[ADDR_W] & valid_int; //selects memory cache (1) or controller (0), using addr's MSB      
   wire                                      write_access = (cache_select &   (|wstrb_int));
   wire                                      read_access =  (cache_select &  ~(|wstrb_int));
   
   //Cache - Memory-Controller signals
   wire [DATA_W-1:0]                         rdata_cache, rdata_ctrl;
   wire                                      ready_cache, ready_ctrl; 
   assign rdata     = (cache_select)? rdata_cache : rdata_ctrl;
   assign ready_int = (cache_select)? ready_cache : ready_ctrl;
   
   //Process connection and controller signals
   wire                                      read_miss, hit, write_full, write_empty, write_en;
   wire                                      line_load, line_load_en;
   wire [MEM_DATA_W-1:0]                     line_load_data;
   wire [MEM_OFFSET_W-1:0]                   word_counter;
   wire [`CTRL_COUNTER_W-1:0]                ctrl_counter;
   wire                                      invalidate;



   generate
      if (LA_INTERF) //Look-Ahead Interface - signal storage
        begin
           reg [ADDR_W   : $clog2(N_BYTES)]         addr_la;
           reg                                      valid_la;
           reg [DATA_W-1 : 0]                       wdata_la;
           reg [N_BYTES-1: 0]                       wstrb_la;
           reg                                      instr_la; //Ctrl's counter

           always @(posedge clk, posedge reset) //ready is a reset
             begin
                if(reset)
                  begin
                     addr_la  <= 0;
                     valid_la <= 0;
                     wdata_la <= 0;
                     wstrb_la <= 0;
                     instr_la <= 0;
                  end
                else
                  if(ready_int)
                    begin
                       addr_la  <= 0;
                       valid_la <= 0;
                       wdata_la <= 0;
                       wstrb_la <= 0;
                       instr_la <= 0;
                    end
                  else
                    if(valid) //updates
                      begin
                         addr_la  <= addr;
                         valid_la <= 1'b1;
                         wdata_la <= wdata;
                         wstrb_la <= wstrb;
                         instr_la <= instr;
                      end
                    else 
                      begin
                         addr_la  <= addr_la;
                         valid_la <= valid_la;
                         wdata_la <= wdata_la;
                         wstrb_la <= wstrb_la;
                         instr_la <= instr_la;
                      end // else: !if(valid)
             end // always @ (posedge clk, posedge ready_int)
           
           //Internal assignment - Multiplexers (to there is no delay)
           assign addr_int  = (valid_la)? addr_la  : addr;
           assign valid_int = (valid_la)? 1'b1     :valid;
           assign wdata_int = (valid_la)? wdata_la :wdata;
           assign wstrb_int = (valid_la)? wstrb_la :wstrb;
           assign instr_int = (valid_la)? instr_la :instr; //only for Controller's counter
        end
      else
        begin
           //Internal assignment - Direct wiring
           assign addr_int  = addr;
           assign valid_int = valid;
           assign wdata_int = wdata;
           assign wstrb_int = wstrb;
           assign instr_int = instr; //only for Controller's counter
        end // else: !if(LA_INTERF)
   endgenerate
   
   
   main_process main_fsm
     (
      .clk(clk),
      .reset(reset),
      .write_access(write_access),
      .read_access(read_access),
      .read_miss(read_miss),
      .line_load(line_load),
      .hit(hit),
      .write_full(write_full),
      .write_empty(write_empty),
      .instr(instr_int),
      .ready(ready_cache),
      .write_en(write_en),
      .ctrl_counter(ctrl_counter)
      );
   
   
   generate
      if(MEM_NATIVE)
        begin
           
           wire [MEM_ADDR_W-1:$clog2(MEM_NBYTES)] mem_addr_read,  mem_addr_write;
           wire                                   mem_valid_read, mem_valid_write;
           
           assign mem_addr =  (line_load)? mem_addr_read : mem_addr_write;
           assign mem_valid = (line_load)? mem_valid_read: mem_valid_write;                   
           
           read_process_native
             #(
               .ADDR_W(ADDR_W),
               .DATA_W(DATA_W),  
               .WORD_OFF_W(WORD_OFF_W),
               .MEM_ADDR_W (MEM_ADDR_W),
               .MEM_DATA_W (MEM_DATA_W)
               )
           read_fsm
             (
              .clk(clk),
              .reset(reset),
              .addr(addr_int[ADDR_W-1:$clog2(N_BYTES)]),
              .read_miss(read_miss), 
              .write_empty(write_empty), 
              .line_load(line_load),
              .line_load_en(line_load_en),
              .word_counter(word_counter),
              .line_load_data(line_load_data),
              .mem_addr(mem_addr_read),
              .mem_valid(mem_valid_read),
              .mem_ready(mem_ready),
              .mem_rdata(mem_rdata)  
              );

           write_process_native
             #(
               .ADDR_W(ADDR_W),
               .DATA_W(DATA_W),
               .WTBUF_DEPTH_W(WTBUF_DEPTH_W),
               .MEM_ADDR_W (MEM_ADDR_W),
               .MEM_DATA_W (MEM_DATA_W)
               )
           write_fsm
             (
              .clk(clk),
              .reset(reset),
              .addr(addr_int[ADDR_W-1:$clog2(N_BYTES)]),
              .wstrb(wstrb_int),
              .wdata(wdata_int),
              .write_empty(write_empty),
              .write_full(write_full),
              .write_en(write_en),
              .mem_addr(mem_addr_write),
              .mem_valid(mem_valid_write),
              .mem_ready(mem_ready),
              .mem_wdata(mem_wdata),
              .mem_wstrb(mem_wstrb)
              );
        end
      else
        begin
           read_process_axi
             #(
               .ADDR_W(ADDR_W),
               .DATA_W(DATA_W),  
               .WORD_OFF_W(WORD_OFF_W),
               .MEM_ADDR_W (MEM_ADDR_W),
               .MEM_DATA_W (MEM_DATA_W),
               .AXI_ID_W(AXI_ID_W),
               .AXI_ID(AXI_ID)
               )
           read_fsm
             (
              .clk(clk),
              .reset(reset),
              .addr(addr_int[ADDR_W-1:$clog2(N_BYTES)]),
              .read_miss(read_miss), 
              .write_empty(write_empty), 
              .line_load(line_load),
              .line_load_en(line_load_en),
              .word_counter(word_counter),
              .line_load_data (line_load_data),
              .axi_arid(axi_arid),
              .axi_araddr(axi_araddr), 
              .axi_arlen(axi_arlen),
              .axi_arsize(axi_arsize),
              .axi_arburst(axi_arburst),
              .axi_arlock(axi_arlock),
              .axi_arcache(axi_arcache),
              .axi_arprot(axi_arprot),
              .axi_arqos(axi_arqos),
              .axi_arvalid(axi_arvalid), 
              .axi_arready(axi_arready),
              .axi_rid(axi_rid),
              .axi_rdata(axi_rdata),
              .axi_rresp(axi_rresp),
              .axi_rlast(axi_rlast), 
              .axi_rvalid(axi_rvalid), 
              .axi_rready(axi_rready)  
              );

           write_process_axi
             #(
               .ADDR_W(ADDR_W),
               .DATA_W(DATA_W),
               .WTBUF_DEPTH_W(WTBUF_DEPTH_W),
               .MEM_ADDR_W (MEM_ADDR_W),
               .MEM_DATA_W (MEM_DATA_W),
               .AXI_ID_W(AXI_ID_W),
               .AXI_ID(AXI_ID)
               )
           write_fsm
             (
              .clk(clk),
              .reset(reset),
              .addr(addr_int[ADDR_W-1:$clog2(N_BYTES)]),
              .wstrb(wstrb_int),
              .wdata(wdata_int),
              .write_empty(write_empty),
              .write_full(write_full),
              .write_en(write_en),
              .axi_awid(axi_awid),
              .axi_awaddr(axi_awaddr), 
              .axi_awlen(axi_awlen),
              .axi_awsize(axi_awsize),
              .axi_awburst(axi_awburst),
              .axi_awlock(axi_awlock),
              .axi_awcache(axi_awcache),
              .axi_awprot(axi_awprot),
              .axi_awqos(axi_awqos),
              .axi_awvalid(axi_awvalid), 
              .axi_awready(axi_awready),
              .axi_wdata(axi_wdata),
              .axi_wstrb(axi_wstrb),
              .axi_wlast(axi_wlast),
              .axi_wvalid(axi_wvalid),
              .axi_wready(axi_wready),
              .axi_bid(axi_bid),
              .axi_bresp(axi_bresp),
              .axi_bvalid(axi_bvalid), 
              .axi_bready(axi_bready)  
              );      
        end
   endgenerate
   
   
   memory_section
     #(
       .ADDR_W(ADDR_W),
       .DATA_W(DATA_W),
       .N_WAYS(N_WAYS),
       .LINE_OFF_W(LINE_OFF_W),
       .WORD_OFF_W(WORD_OFF_W),
       .MEM_DATA_W(MEM_DATA_W)
       )
   memory_cache
     (
      .clk  (clk),
      .reset(reset),
      .addr (addr_int[ADDR_W-1:$clog2(N_BYTES)]),
      .wdata(wdata_int),
      .wstrb(wstrb_int),
      .rdata(rdata_cache),
      .valid(valid_int & cache_select),
      .line_load_data(line_load_data),
      .line_load(line_load),
      .line_load_en(line_load_en),
      .word_counter(word_counter),
      .hit(hit),
      .write_en(write_en),
      .invalidate(invalidate)
      );

   
   cache_controller
     #(
       .DATA_W     (DATA_W),
       .CTRL_CNT   (CTRL_CNT),
       .CTRL_CNT_ID(CTRL_CNT_ID)
       )
   cache_control
     (
      .clk(clk),
      .din(ctrl_counter),
      .invalidate(invalidate),
      .addr(addr_int[`ADDR_W-1 + $clog2(N_BYTES):$clog2(N_BYTES)]),
      .dout(rdata_ctrl),
      .valid(valid_int & ~cache_select),
      .ready(ready_ctrl),
      .reset(reset),
      .write_state({write_full,write_empty})
      );
   
endmodule // iob_cache



/*--------------*/
/* Main Process */ 
/*--------------*/
//Cache's main process, that controls the current cache's state based on the other processes

module main_process
  #(
    parameter CTRL_CNT_ID = 0,
    parameter CTRL_CNT = 1
    )
   (
    input                            clk,
    input                            reset,
    input                            write_access,
    input                            read_access,
    output reg                       read_miss, 
    input                            line_load,
    input                            hit,
    input                            write_full,
    input                            write_empty,
    input                            instr,
    output reg                       ready,
    output reg                       write_en,
    output reg [`CTRL_COUNTER_W-1:0] ctrl_counter
    );
   
   
   localparam
     idle          = 2'd0,
     write_standby = 2'd1,
     read_standby  = 2'd2,
     read_process  = 2'd3;
   
   
   reg [1:0]                         state;
   
   always @(posedge clk, posedge reset)
     begin
        if (reset)
          state <= idle;
        else
          case (state)
            idle:
              begin
                 if (read_access)
                   state <= read_standby;
                 else
                   if(write_access)
                     state <= write_standby;
                   else
                     state <= idle;
              end
            
            write_standby:
              begin
                 if (write_full)
                   state <= write_standby;
                 else
                   state <= idle;
              end

            read_standby:
              begin
                 if(hit)
                   state <= idle;
                 else 
                   if(write_empty)   
                     state <= read_process; //read-miss, needs a line load
                   else
                     state <= read_standby;
              end

            read_process: //line_load
              begin
                 if (~line_load)
                   state <= idle;
                 else
                   state <= read_process;
              end

            default:;

          endcase // case (state)
     end // always @ (posedge clk, posedge reset)


   always @*
     begin
        read_miss = 1'b0;
        ready = 1'b0;
        write_en = 1'b0;
        
	case (state)
          idle:
            begin
               ready = 1'b0;
               write_en = 1'b0;
            end

          write_standby:
            begin
               ready = ~write_full; // ends process if isn't full, regardless if hit or miss
               write_en = ~write_full;
            end
          

          read_standby:
            begin
               ready = hit; // if it was a hit, the data in rdata is the correct one
               write_en = hit; //update replacement policy algorithm
               if(~hit & write_empty)
                 read_miss = 1'b1; //so the hit signal is properly updated (memory read-latency) and only starts after everything has been written to the top memory
            end
          
          read_process:
            begin  
               write_en = ~line_load;
               ready = ~line_load;                           
            end
        endcase
     end

   generate
      if(CTRL_CNT_ID)
        begin
           always @*
             begin
                ctrl_counter = `CTRL_COUNTER_W'd0;
                
	        case (state)
                  idle:
                    ctrl_counter = `CTRL_COUNTER_W'd0;
                  
                  write_standby:
                    if (~write_full)
                      if(hit)
                        ctrl_counter = `WRITE_HIT;
                      else
                        ctrl_counter = `WRITE_MISS;
                    else
                      ctrl_counter = `CTRL_COUNTER_W'd0;
                  

                  read_standby:
                    if (hit)
                      if(instr)
                        ctrl_counter = `INSTR_HIT;
                      else
                        ctrl_counter = `READ_HIT;
                    else
                      if(write_empty)
                        if(instr)
                          ctrl_counter = `INSTR_MISS;
                        else
                          ctrl_counter = `READ_MISS;
                      else
                        ctrl_counter = `CTRL_COUNTER_W'd0;
                  
                  default:;   
                endcase
             end // always @ *
        end // if (CTRL_CNT_ID)
      else if (CTRL_CNT)
        begin
           always @*
             begin
                ctrl_counter = `CTRL_COUNTER_W'd0;
                
	        case (state)
                  idle:
                    ctrl_counter = `CTRL_COUNTER_W'd0;

                  write_standby:
                    if (~write_full)
                      if(hit)
                        ctrl_counter = `WRITE_HIT;
                      else
                        ctrl_counter = `WRITE_MISS;
                    else
                      ctrl_counter = `CTRL_COUNTER_W'd0;
                  

                  read_standby:
                    if (hit)
                      ctrl_counter = `READ_HIT;
                    else
                      if(write_empty)
                        ctrl_counter = `READ_MISS;
                      else
                        ctrl_counter = `CTRL_COUNTER_W'd0;         
                endcase
             end   
        end
   endgenerate
   
   
endmodule            


/*--------------*/
/* Read Process */ 
/*--------------*/
// Process that loads a cache line, in the occurence of a read-miss

module read_process_axi 
  #(
    parameter ADDR_W   = 32,
    parameter DATA_W   = 32,
    parameter WORD_OFF_W = 3,
    parameter N_BYTES  = DATA_W/8,
    parameter BYTES_W = $clog2(N_BYTES), //Offset of the Number of Bytes per Word
    //Higher hierarchy memory (slave) interface parameters 
    parameter MEM_ADDR_W = ADDR_W, //Address width of the higher hierarchy memory
    parameter MEM_DATA_W = DATA_W, //Data width of the memory 
    parameter MEM_NBYTES = MEM_DATA_W/8, //Number of bytes
    parameter MEM_BYTES_W = $clog2(MEM_NBYTES), //Offset of the Number of Bytes
    //AXI specific parameters
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0,  //AXI ID value
    //Cache-Memory base Offset
    parameter MEM_OFFSET_W = WORD_OFF_W-$clog2(MEM_DATA_W/DATA_W) //burst offset based on the cache's word and memory word size
    )
   (
    input                              clk,
    input                              reset,
    input [ADDR_W -1: $clog2(N_BYTES)] addr,
    input                              read_miss, //read access that results in a cache miss
    input                              write_empty, //write_process has an empty buffer
    output reg                         line_load, //load cache line with new data
    output                             line_load_en,//Memory enable during the cache line load
    output reg [MEM_OFFSET_W-1:0]      word_counter,//counter to enable each word in the line
    output [MEM_DATA_W-1:0]            line_load_data,//data to load the cache line  
    // AXI interface  
    //Address Read
    output [AXI_ID_W-1:0]              axi_arid,
    output [MEM_ADDR_W-1:0]            axi_araddr, 
    output [7:0]                       axi_arlen,
    output [2:0]                       axi_arsize,
    output [1:0]                       axi_arburst,
    output [0:0]                       axi_arlock,
    output [3:0]                       axi_arcache,
    output [2:0]                       axi_arprot,
    output [3:0]                       axi_arqos,
    output reg                         axi_arvalid, 
    input                              axi_arready,
    //Read
    input [AXI_ID_W-1:0]               axi_rid,
    input [MEM_DATA_W-1:0]             axi_rdata,
    input [1:0]                        axi_rresp,
    input                              axi_rlast, 
    input                              axi_rvalid, 
    output reg                         axi_rready
    );

   //Constant AXI signals
   assign axi_arid    = AXI_ID;
   assign axi_arlock  = 1'b0;
   assign axi_arcache = 4'b0011;
   assign axi_arprot  = 3'd0;
   assign axi_arqos   = 4'd0;
   //Burst parameters
   // assign axi_arlen   = (MEM_DATA_W/DATA_W)*2**WORD_OFF_W -1; //will choose the burst lenght depending on the cache's and slave's data width
   assign axi_arlen   = 2**MEM_OFFSET_W -1; //will choose the burst lenght depending on the cache's and slave's data width
   assign axi_arsize  = MEM_BYTES_W; //each word will be the width of the memory for maximum bandwidth
   assign axi_arburst = 2'b01; //incremental burst
   assign axi_araddr  = {{(MEM_ADDR_W-ADDR_W){1'b0}}, addr[ADDR_W-1:MEM_OFFSET_W + MEM_BYTES_W], {(MEM_OFFSET_W+MEM_BYTES_W){1'b0}}}; //base address for the burst, with width extension 

   //Line Load signals
   assign line_load_en   = axi_rvalid;
   assign line_load_data = axi_rdata;
   
   
   localparam
     idle          = 2'd0,
     init_process  = 2'd1,
     load_process  = 2'd2,
     end_process   = 2'd3;
   
   
   reg [1:0]                           state;

   
   always @(posedge clk, posedge reset)
     begin
        if(reset)
          begin
             state <= idle;
             word_counter <= 0;
          end
        else
           
          case (state)   
            idle:
              begin
                 word_counter <= 0;  
                 if(read_miss)
                   state <= init_process;
                 else
                   state <= idle;
              end

            init_process:
              begin
                 word_counter <= 0;  
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
                        word_counter <= word_counter; //to avoid writting last data in first line word
                     end
                   else
                     begin
                        word_counter <= word_counter +1;
                        state <= load_process;
                     end
                 else
                   begin
                      word_counter <= word_counter;
                      state <= load_process;
                   end
              end

            end_process://delay for the read_latency of the memories (if the rdata is the last word)
              state <= idle;
            
            
            default:;
          endcase
     end
   
   
   always @*
     begin
        axi_arvalid  = 1'b0;
        axi_rready   = 1'b0;
        line_load    = 1'b0;
        case(state)

          idle:
            begin
               line_load    = 1'b0;
               axi_arvalid  = 1'b0;
               axi_rready   = 1'b0;
            end
          
          init_process:
            begin
               line_load   = 1'b1;
               axi_arvalid = 1'b1;
               axi_rready  = 1'b1;
            end

          load_process:
            begin
               line_load   = 1'b1;
               axi_arvalid = 1'b0;
               axi_rready  = 1'b1;             
            end

          end_process:
            line_load = 1'b1; //delay for the memory update (read-latency)
          
          default:;
          
        endcase
     end
   
endmodule



module read_process_native
  #(
    parameter ADDR_W   = 32,
    parameter DATA_W   = 32,
    parameter N_BYTES  = DATA_W/8,
    parameter WORD_OFF_W = 3,
    //Higher hierarchy memory (slave) interface parameters 
    parameter MEM_ADDR_W = ADDR_W, //Address width of the higher hierarchy memory
    parameter MEM_DATA_W = DATA_W, //Data width of the memory 
    parameter MEM_NBYTES = MEM_DATA_W/8, //Number of bytes
    parameter MEM_BYTES_W = $clog2(MEM_NBYTES), //Offset of the Number of Bytes
    //Cache-Memory base Offset
    parameter MEM_OFFSET_W = WORD_OFF_W-$clog2(MEM_DATA_W/DATA_W) //burst offset based on the cache word's and memory word size
    )
   (
    input                                     clk,
    input                                     reset,
    input [ADDR_W -1: $clog2(N_BYTES)]        addr,
    input                                     read_miss, //read access that results in a cache miss
    input                                     write_empty, //write_process has an empty buffer
    output reg                                line_load, //load cache line with new data
    output                                    line_load_en,//Memory enable during the cache line load
    output reg [MEM_OFFSET_W-1:0]             word_counter,//counter to enable each word in the line
    output [MEM_DATA_W-1:0]                   line_load_data,//data to load the cache line  
    //Native memory interface
    output [MEM_ADDR_W -1:$clog2(MEM_NBYTES)] mem_addr,
    output reg                                mem_valid,
    input                                     mem_ready,
    input [MEM_DATA_W-1:0]                    mem_rdata
    );

   assign mem_addr  = {{(MEM_ADDR_W-ADDR_W){1'b0}}, addr[ADDR_W -1: MEM_BYTES_W + MEM_OFFSET_W], word_counter};
   
   //Cache Line Load signals
   assign line_load_en = mem_ready & mem_valid & line_load;
   assign line_load_data = mem_rdata;

   localparam
     idle             = 2'd0,
     handshake        = 2'd1, //the process was divided in 2 handshake steps to cause a delay in the
     handshake_update = 2'd2, //valid signal so it would work with simple "ready" replies of BRAMs
     end_handshake    = 2'd3; //(always 1 or a delayed valid signal), otherwise it will fail
   
   
   reg [1:0]                                  state;

   always @(posedge clk, posedge reset)
     begin
        if(reset)
          begin
             state <= idle;
          end
        else
          begin
             
             case(state)

               idle:
                 begin
                    if(read_miss) //main_process flag
                      state <= handshake;
                    else
                      state <= idle;
                 end
               
               handshake:
                 begin
                    if(mem_ready)
                      if(&word_counter)
                        state <= end_handshake;
                      else
                        begin
                           state <= handshake_update;
                        end
                    else
                      begin
                         state <= handshake;
                      end
                 end
               
               handshake_update: //update word-counter
                 begin
                    state <= handshake;
                 end
               
               end_handshake: //read-latency delay (last line word)
                 begin
                    state <= idle;
                 end
               
               default:;
               
             endcase                                                     
          end         
     end
   
   
   always @*
     begin 
        word_counter =0;
        
        case(state)
          
          idle:
            begin
               mem_valid = 1'b0;
               line_load = 1'b0;
               word_counter = 0;
            end

          handshake:
            begin
               mem_valid = 1'b1;
               line_load = 1'b1;
               word_counter = word_counter;
            end
          
          handshake_update:
            begin
               mem_valid = 1'b0;
               line_load =1'b1;
               word_counter = word_counter +1;
            end

          end_handshake:
            begin
               word_counter = word_counter; //to avoid updating the first word in line with last data
               line_load = 1'b1; //delay for read-latency
               mem_valid = 1'b0;
            end
          
          default:;
          
        endcase
     end
   
endmodule



/* ------------- */
/* Write process */
/* ------------- */
// Process responsible to write data to the upper-level memory

module write_process_axi
  #(
    parameter ADDR_W   = 32,
    parameter DATA_W   = 32,
    parameter N_BYTES  = DATA_W/8,
    parameter BYTES_W = $clog2(N_BYTES), //Offset of the Number of Bytes per Word
    parameter WTBUF_DEPTH_W = 4,
    //Higher hierarchy memory (slave) interface parameters 
    parameter MEM_ADDR_W = ADDR_W, //Address width of the higher hierarchy memory
    parameter MEM_DATA_W = DATA_W, //Data width of the memory 
    parameter MEM_NBYTES = MEM_DATA_W/8, //Number of bytes
    parameter MEM_BYTES_W = $clog2(MEM_NBYTES), //Offset of the Number of Bytes
    //AXI specific parameters
    parameter AXI_ID_W              = 1, //AXI ID (identification) width
    parameter [AXI_ID_W-1:0] AXI_ID = 0  //AXI ID value
    ) 
   (
    input                            clk,
    input                            reset,
    input [ADDR_W-1:$clog2(N_BYTES)] addr,
    input [N_BYTES-1:0]              wstrb,
    input [DATA_W-1:0]               wdata,
    // Buffer status
    output reg                       write_empty,
    output                           write_full,
    // Buffer write enable
    input                            write_en,
    // AXI interface 
    // Address Write
    output [AXI_ID_W-1:0]            axi_awid, 
    output [MEM_ADDR_W-1:0]          axi_awaddr,
    output [7:0]                     axi_awlen,
    output [2:0]                     axi_awsize,
    output [1:0]                     axi_awburst,
    output [0:0]                     axi_awlock,
    output [3:0]                     axi_awcache,
    output [2:0]                     axi_awprot,
    output [3:0]                     axi_awqos,
    output reg                       axi_awvalid,
    input                            axi_awready,
    //Write                  
    output [MEM_DATA_W-1:0]          axi_wdata,
    output [MEM_NBYTES-1:0]          axi_wstrb,
    output                           axi_wlast,
    output reg                       axi_wvalid, 
    input                            axi_wready,
    input [AXI_ID_W-1:0]             axi_bid,
    input [1:0]                      axi_bresp,
    input                            axi_bvalid,
    output reg                       axi_bready
    );

   //Write-through buffer
   wire [N_BYTES+(ADDR_W-BYTES_W)+(DATA_W) -1 :0] buffer_dout, buffer_din; 
   reg                                            buffer_read_en;
   wire                                           buffer_empty, buffer_full;
   
   assign buffer_din = {addr,wstrb,wdata};

   assign write_full = buffer_full;
   
   //Constant AXI signals
   assign axi_awid    = AXI_ID;
   assign axi_awlen   = 8'd0;
   assign axi_awsize  = 3'b010;
   assign axi_awburst = 2'd0;
   assign axi_awlock  = 1'b0; // 00 - Normal Access
   assign axi_awcache = 4'b0011;
   assign axi_awprot  = 3'd0;
   assign axi_awqos   = 4'd0;
   assign axi_wlast   = axi_wvalid;
   
   //AXI Buffer Output signals
   assign axi_awaddr = {{(MEM_ADDR_W-ADDR_W){1'b0}}, buffer_dout[DATA_W+N_BYTES + (MEM_BYTES_W-BYTES_W) +: ADDR_W-(MEM_BYTES_W)], {MEM_BYTES_W{1'b0}}}; 
   generate
      if(MEM_DATA_W == DATA_W)
        begin
           assign axi_wstrb = buffer_dout[DATA_W +: N_BYTES];
           assign axi_wdata =  {{(MEM_DATA_W-DATA_W){1'b0}}, buffer_dout[DATA_W-1:0]};
           
        end
      else
        begin
           wire [MEM_BYTES_W - BYTES_W -1 :0] addr_shift = buffer_dout[DATA_W+N_BYTES +: (MEM_BYTES_W-BYTES_W)];//addr[BYTES_W +: (MEM_BYTES_W - BYTES_W)]
           assign axi_wstrb = buffer_dout[DATA_W+N_BYTES -1 -:N_BYTES] << addr_shift * N_BYTES;
           assign axi_wdata = buffer_dout[DATA_W -1 : 0] << addr_shift * DATA_W;
        end
   endgenerate
   
   
   localparam
     idle           = 3'd0,
     init_process   = 3'd1,
     addr_process   = 3'd2,
     write_process  = 3'd3,
     verif_process  = 3'd4;  
   
   reg [3:0]                                  state;

   
   always @(posedge clk, posedge reset)
     begin
        if(reset)
          state <= idle;
        else
          case(state)

            idle:
              begin
                 if(buffer_empty)
                   state <= idle;
                 else
                   state <= init_process;
              end

            init_process://update write-through buffer
              begin
                 state <= addr_process;
              end
            
            addr_process:
              begin
                 if(axi_awready)
                   state <= write_process;
                 
                 else
                   state <= init_process;
              end

            write_process:
              begin
                 if (axi_wready)
                   state <= verif_process;
                 else
                   state <= write_process;
              end

            verif_process:
              begin
                 if(axi_bvalid)
                   if(~axi_bresp[1])//00 or 01 - OKAY
                     if(buffer_empty)
                       state <= idle;
                     else
                       state <= init_process;
                   else
                     state <= init_process; //wasn't well written
                 else
                   state <= verif_process;
              end

            default: ;         

          endcase 
     end // always @ (posedge clk, posedge reset)
   
   
   always @*
     begin
        buffer_read_en = 1'b0;
        axi_awvalid    = 1'b0;
        axi_wvalid     = 1'b0;
        axi_bready     = 1'b0;
        write_empty    = 1'b0;        
        case(state)
          idle:
            write_empty = buffer_empty;
          init_process:
            buffer_read_en = 1'b1;
          addr_process:
            axi_awvalid = 1'b1;
          write_process:
            axi_wvalid  = 1'b1;
          verif_process:
            axi_bready  = 1'b1;
          default:;
        endcase
     end       

   
   iob_async_fifo #(
		    .DATA_WIDTH (N_BYTES+ADDR_W-BYTES_W+DATA_W),
		    .ADDRESS_WIDTH (WTBUF_DEPTH_W)
		    ) 
   write_throught_buffer 
     (
      .rst     (reset               ),
      .data_out(buffer_dout         ), 
      .empty   (buffer_empty        ),
      .level_r (),
      .read_en (buffer_read_en      ),
      .rclk    (clk                 ),    
      .data_in (buffer_din          ), 
      .full    (buffer_full         ),
      .level_w (),
      .write_en((|wstrb) && write_en),
      .wclk    (clk                 )
      );

endmodule


module write_process_native
  #(
    parameter ADDR_W   = 32,
    parameter DATA_W   = 32,
    parameter N_BYTES  = DATA_W/8,
    parameter BYTES_W = $clog2(N_BYTES), //Offset of the Number of Bytes per Word
    parameter WTBUF_DEPTH_W = 4,
    //Higher hierarchy memory (slave) interface parameters 
    parameter MEM_ADDR_W = ADDR_W, //Address width of the higher hierarchy memory
    parameter MEM_DATA_W = DATA_W, //Data width of the memory 
    parameter MEM_NBYTES = MEM_DATA_W/8, //Number of bytes
    parameter MEM_BYTES_W = $clog2(MEM_NBYTES) //Offset of the Number of Bytes
    ) 
   (
    input                                     clk,
    input                                     reset,
    input [ADDR_W-1:$clog2(N_BYTES)]          addr,
    input [N_BYTES-1:0]                       wstrb,
    input [DATA_W-1:0]                        wdata,
    // Buffer status
    output reg                                write_empty,
    output                                    write_full,
    // Buffer write enable
    input                                     write_en,
    //Native Memory interface
    output [MEM_ADDR_W -1:$clog2(MEM_NBYTES)] mem_addr,
    output reg                                mem_valid,
    input                                     mem_ready,
    output [MEM_DATA_W-1:0]                   mem_wdata,
    output reg [MEM_NBYTES-1:0]               mem_wstrb
   
    );

   //Write-through buffer
   wire [N_BYTES+(ADDR_W-$clog2(N_BYTES))+(DATA_W) -1 :0] buffer_dout, buffer_din; 
   reg                                                    buffer_read_en;
   wire                                                   buffer_empty, buffer_full;
   
   assign buffer_din = {addr,wstrb,wdata};

   assign write_full = buffer_full;
   
   //Native Buffer Output signals
   assign mem_addr = {{(MEM_ADDR_W-ADDR_W){1'b0}}, buffer_dout[DATA_W+N_BYTES + (MEM_BYTES_W-BYTES_W) +: ADDR_W-(MEM_BYTES_W)]}; 
   
   localparam
     idle          = 3'd0,
     init_process  = 3'd1,
     write_process = 3'd2;
   
   reg [1:0]                                              state;

   generate
      if(MEM_DATA_W == DATA_W)
        begin
           
           assign mem_wdata = buffer_dout [DATA_W -1 : 0];
           
           always @*
             begin
                mem_wstrb = 0;
                case(state)
                  write_process:
                    begin
                       mem_wstrb = buffer_dout [DATA_W +: N_BYTES];
                    end
                  default:;
                endcase // case (state)
             end // always @ *
           
        end
      else
        begin
           
           wire [MEM_BYTES_W - BYTES_W -1 :0] addr_shift = buffer_dout[DATA_W+N_BYTES +: (MEM_BYTES_W-BYTES_W)];//addr[BYTES_W +: (MEM_BYTES_W - BYTES_W)]
           assign mem_wdata = buffer_dout [DATA_W -1 : 0] << addr_shift * DATA_W ;
           
           always @*
             begin
                mem_wstrb = 0;
                case(state)
                  write_process:
                    begin
                       mem_wstrb = buffer_dout[DATA_W+N_BYTES -1 -:N_BYTES] << addr_shift * N_BYTES;
                    end
                  default:;
                endcase // case (state)
             end 
           
        end
   endgenerate

   always @(posedge clk, posedge reset)
     begin
        if(reset)
          state <= idle;
        else
          case(state)

            idle:
              begin
                 if(buffer_empty)
                   state <= idle;
                 else
                   state <= init_process;
              end

            init_process:
              begin
                 state <= write_process;
              end

            write_process:
              begin
                 if(mem_ready)
                   state <= idle;
                 else
                   state <= write_process;
              end

            default:;
          endcase // case (state)
     end // always @ (posedge clk, posedge reset)

   always @*
     begin
        write_empty    = 1'b0;
        buffer_read_en = 1'b0;
        mem_valid      = 1'b0;
        case(state)
          idle:
            write_empty = buffer_empty;
          init_process:
            buffer_read_en = 1'b1; //update buffer in it's read port
          write_process:
            mem_valid = 1'b1;
          default:;
        endcase // case (state)
     end
   
   
   iob_async_fifo #(
		    .DATA_WIDTH (N_BYTES+ADDR_W-BYTES_W+DATA_W),
		    .ADDRESS_WIDTH (WTBUF_DEPTH_W)
		    ) 
   write_throught_buffer 
     (
      .rst     (reset               ),
      .data_out(buffer_dout         ), 
      .empty   (buffer_empty        ),
      .level_r (),
      .read_en (buffer_read_en      ),
      .rclk    (clk                 ),    
      .data_in (buffer_din          ), 
      .full    (buffer_full         ),
      .level_w (),
      .write_en((|wstrb) && write_en),
      .wclk    (clk                 )
      );

endmodule



/*----------------*/
/* Memory Section */
/*----------------*/
//Module that contains all the memories as well as the replacement policies in case necessary

module memory_section 
  #(
    //memory cache's parameters
    parameter ADDR_W   = 32,       //Address width - width that will used for the cache 
    parameter DATA_W   = 32,       //Data width - word size used for the cache
    parameter N_WAYS   = 1,        //Number of Cache Ways
    parameter LINE_OFF_W  = 6,      //Line-Offset Width - 2**NLINE_W total cache lines
    parameter WORD_OFF_W = 3,       //Word-Offset Width - 2**OFFSET_W total DATA_W words per line 
    //Do NOT change - memory cache's parameters - dependency
    parameter NWAY_W   = $clog2(N_WAYS), //Cache Ways Width
    parameter N_BYTES  = DATA_W/8,      //Number of Bytes per Word
    parameter BYTES_W = $clog2(N_BYTES), //Offset of the Number of Bytes per Word
    /*---------------------------------------------------*/
    //Higher hierarchy memory (slave) interface parameters 
    parameter MEM_DATA_W = DATA_W, //Data width of the memory
    parameter MEM_NBYTES = MEM_DATA_W/8, //Number of bytes
    //Do NOT change - slave parameters - dependency
    parameter MEM_OFFSET_W = WORD_OFF_W-$clog2(MEM_DATA_W/DATA_W) //burst offset based on the cache and memory word size
    )
   ( 
     //master interface
     input                            clk,
     input                            reset,
     input [ADDR_W-1:$clog2(N_BYTES)] addr,
     input [DATA_W-1:0]               wdata,
     input [N_BYTES-1:0]              wstrb,
     output [DATA_W-1:0]              rdata,
     input                            valid,
     //slave interface
     input [MEM_DATA_W-1:0]           line_load_data,
     //
     input                            line_load, //process of loading the cache-line
     input                            line_load_en, //enable for during a cache line load
     input [MEM_OFFSET_W-1:0]         word_counter, //selects the cache-line words elligible to be written
     output                           hit, //cache-hit(1), cache-miss(0)
     input                            write_en, //global enable
     input                            invalidate   //invalidate entire cache
     );
   
   localparam TAG_W = ADDR_W - (BYTES_W+WORD_OFF_W+LINE_OFF_W);

   wire [N_WAYS-1:0]                  way_hit, v;
   wire [N_WAYS*TAG_W-1:0]            tag;
   assign hit = |way_hit;
   
   wire [N_WAYS*(2**WORD_OFF_W)*DATA_W-1:0] line_rdata;
   wire [LINE_OFF_W-1:0]                    line_addr = addr[BYTES_W + WORD_OFF_W +: LINE_OFF_W];
   wire [TAG_W-1:0]                         line_tag  = addr[            ADDR_W-1 -: TAG_W     ];
   wire [WORD_OFF_W-1:0]                    line_word_select = addr[      BYTES_W +: WORD_OFF_W];
   reg [N_WAYS*(2**WORD_OFF_W)*N_BYTES-1:0] line_wstrb;
   
   
   genvar                                   i,j,k;
   generate
      if(N_WAYS != 1)
        begin
           wire [NWAY_W-1:0] way_hit_bin, way_select;//reason for the 2 generates for single vs multiple ways
           
           
           replacement_process #(
	                         .N_WAYS    (N_WAYS    ),
	                         .LINE_OFF_W(LINE_OFF_W)
	                         )
           replacement_policy_algorithm
             (
              .clk       (clk             ),
              .reset     (reset|invalidate),
              .write_en  (write_en        ),
              .way_hit   (way_hit         ),
              .line_addr (line_addr       ),
              .way_select(way_select      )
              );
           
           onehot_to_bin #(
                           .BIN_W (NWAY_W)
                           ) 
           way_hit_encoder
             (
              .onehot(way_hit    ),
              .bin   (way_hit_bin)
              );

           
           //Read Data Multiplexer
           assign rdata [DATA_W-1:0] = line_rdata >> DATA_W*(line_word_select + (2**WORD_OFF_W)*way_hit_bin);
           
           //Cache Line Write Strobe Shifter
           always @*
             if(line_load)
               line_wstrb = {MEM_NBYTES{1'b1}} << (word_counter*MEM_NBYTES + way_select*(2**WORD_OFF_W)*N_BYTES);
             else
               line_wstrb = (wstrb & {N_BYTES{write_en}}) << (line_word_select*N_BYTES + way_hit_bin*(2**WORD_OFF_W)*N_BYTES);

           for (k = 0; k < N_WAYS; k=k+1)
             begin
                for(j = 0; j < 2**MEM_OFFSET_W; j=j+1)
                  begin
                     for(i = 0; i < MEM_DATA_W/DATA_W; i=i+1)
                       begin
                          iob_sp_mem_be
                             #(
                               .NUM_COL   (N_BYTES),
                               .COL_WIDTH (8),
                               .ADDR_WIDTH(LINE_OFF_W)
                               )
                          cache_memory 
                             (
                              .clk (clk),
                              .en  (valid), //so it can display rdata 1 cycle sooner (otherwise if also used wayt_hit)
                              .we  (((line_load_en & (k == way_select)) | way_hit[k])? line_wstrb[(k*(2**WORD_OFF_W)+j*(MEM_DATA_W/DATA_W)+i)*N_BYTES +: N_BYTES] : {N_BYTES{1'b0}}),
                              .addr(line_addr),
                              .din ((line_load)? line_load_data[i*DATA_W +: DATA_W] : wdata),
                              .dout(line_rdata[(k*(2**WORD_OFF_W)+j*(MEM_DATA_W/DATA_W)+i)*DATA_W +: DATA_W])
                              );
                       end // for (i = 0; i < 2**WORD_OFF_W; i=i+1)
                  end // for (j = 0; j < 2**MEM_OFFSET_W; j=j+1)
                iob_reg_file
                  #(
                    .ADDR_WIDTH(LINE_OFF_W), 
                    .COL_WIDTH (1),
                    .NUM_COL   (1)
	            ) 
	        valid_memory 
	          (
	           .clk  (clk                                ),
	           .rst  (reset|invalidate                   ),
	           .wdata(line_load                          ),				       
	           .addr (line_addr                          ),
	           .en   ((k == way_select)? line_load : 1'b0),
	           .rdata(v[k]                               )   
	           );

                iob_sp_mem_be
                  #(
                    .NUM_COL   (1),
                    .COL_WIDTH (TAG_W),
                    .ADDR_WIDTH(LINE_OFF_W)
                    )
                tag_memory 
                  (
                   .clk (clk                                ),
                   .en  (valid                              ), 
                   .we  ((k == way_select)? line_load : 1'b0),
                   .addr(line_addr                          ),
                   .din (line_tag                           ),
                   .dout(tag[TAG_W*k +: TAG_W]              )
                   );

                //Cache hit signal that indicates which way has had the hit
                assign way_hit[k] = (line_tag == tag[TAG_W*k +: TAG_W]) &&  v[k]; // to reduce UNDEFINES in simulation
                
             end // for (k = 0; k < N_WAYS; k=k+1)
           
        end // if (N_WAYS != 1)
      else
        begin   
           
           //Read Data Multiplexer
           assign rdata [DATA_W-1:0] = line_rdata >> DATA_W*(line_word_select);

           //Cache Line Write Strobe Shifter
           always @*
             if(line_load)
               line_wstrb = {MEM_NBYTES{1'b1}} << (word_counter*MEM_NBYTES);
             else
               line_wstrb = wstrb << (line_word_select*N_BYTES);


           for(j = 0; j < 2**MEM_OFFSET_W; j=j+1)
             begin
                for(i = 0; i < MEM_DATA_W/DATA_W; i=i+1)
                  begin
                     iob_sp_mem_be
                        #(
                          .NUM_COL   (N_BYTES),
                          .COL_WIDTH (8),
                          .ADDR_WIDTH(LINE_OFF_W)
                          )
                     cache_memory 
                        (
                         .clk (clk),
                         .en (valid),
                         .we  ((line_load_en | way_hit)? line_wstrb[(j*(MEM_DATA_W/DATA_W)+i)*N_BYTES +: N_BYTES] : {N_BYTES{1'b0}}), 
                         .addr(line_addr),
                         .din ((line_load)? line_load_data[i*DATA_W +: DATA_W] : wdata),
                         .dout(line_rdata[(j*(MEM_DATA_W/DATA_W)+i)*DATA_W +: DATA_W])
                         );
                  end // for (i = 0; i < 2**WORD_OFF_W; i=i+1)
             end // for (j = 0; j < 2**MEM_OFFSET_W; j=j+1)  
           iob_reg_file
             #(
               .ADDR_WIDTH(LINE_OFF_W), 
               .COL_WIDTH (1),
               .NUM_COL   (1)
	       ) 
	   valid_memory 
	     (
	      .clk  (clk             ),
	      .rst  (reset|invalidate),
	      .wdata(line_load       ),				       
	      .addr (line_addr       ),
	      .en   (line_load       ),
	      .rdata(v               )   
	      );

           iob_sp_mem_be
             #(
               .NUM_COL   (1),
               .COL_WIDTH (TAG_W),
               .ADDR_WIDTH(LINE_OFF_W)
               )
           tag_memory 
             (
              .clk (clk      ),
              .en  (valid    ), 
              .we  (line_load),
              .addr(line_addr),
              .din (line_tag ),
              .dout(tag      )
              );

           //Cache hit signal that indicates which way has had the hit
           assign way_hit = (line_tag == tag) & v;
           
        end
   endgenerate
endmodule // memory_section



/*---------------------------*/
/* One-Hot to Binary Encoder */
/*---------------------------*/

// One-hot to binary encoder (if input is (0)0 or (0)1, the output is 0)
module onehot_to_bin 
  #(
    parameter BIN_W = 2
    )
   (
    input [2**BIN_W-1:0]   onehot,
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



/*--------------------*/
/* Replacement Policy */
/*--------------------*/
// Module that contains all iob-cache's replacement policies

module replacement_process 
  #(
    parameter N_WAYS     = 2,
    parameter LINE_OFF_W = 2,
    parameter NWAY_W = $clog2(N_WAYS)
    )
   (
    input                  clk,
    input                  reset,
    input                  write_en,
    input [2**NWAY_W-1:0]  way_hit,
    input [LINE_OFF_W-1:0] line_addr,
    output [NWAY_W-1:0]    way_select 
    );

`ifdef BIT_PLRU
   wire [N_WAYS -1:0]      mru_output;
   wire [N_WAYS -1:0]      mru_input = (&(mru_output | way_hit))? {N_WAYS{1'b0}} : mru_output | way_hit; //When the cache access results in a hit (or access (wish would be 1 in way_hit even during a read-miss), it will add to the MRU, if after the the OR with Way_hit, the entire input is 1s, it resets
   wire [N_WAYS -1:0]      bitplru = (~mru_output); //least recent used
   wire [0:N_WAYS -1]      bitplru_liw = bitplru [N_WAYS -1:0]; //LRU Lower-Line_addr-Way priority
   wire [(N_WAYS**2)-1:0]  ext_bitplru;// Extended LRU
   wire [(N_WAYS**2)-(N_WAYS)-1:0] cmp_bitplru;//Result for the comparision of the LRU values (lru_liw), to choose the lowest line_addr way for replacement. All the results of the comparision will be placed in the wire. This way the comparing all the Ways will take 1 clock cycle, instead of 2**NWAY_W cycles.
   wire [N_WAYS-1:0]               bitplru_sel;  

   genvar                          i;
   generate
      for (i = 0; i < N_WAYS; i=i+1)
	begin
	   assign ext_bitplru [((i+1)*N_WAYS)-1 : i*N_WAYS] = bitplru_liw[i] << (N_WAYS-1 -i); // extended signal of the LRU, placing the lower line_addres in the higher positions (higher priority)
	end

      assign cmp_bitplru [N_WAYS-1:0] = (bitplru_liw[i])? ext_bitplru[2*(N_WAYS)-1: N_WAYS] : ext_bitplru[N_WAYS -1: 0]; //1st iteration: higher line_addr in lru_liw is the lower line_addres in LRU, if the lower line_addr is bit-PLRU, it's stored their extended value
      
      for (i = 2; i < N_WAYS; i=i+1)
	begin
	   assign cmp_bitplru [((i)*N_WAYS)-1 : (i-1)*N_WAYS] = (bitplru_liw[i])? ext_bitplru [i*N_WAYS +: N_WAYS] : cmp_bitplru [(i-2)*N_WAYS +: N_WAYS]; //if the Lower line_addr of LRU is valid for replacement (LRU), it's placed, otherwise keeps the previous value
	end
   endgenerate
   assign bitplru_sel = cmp_bitplru [(N_WAYS**2)-(N_WAYS)-1 :(N_WAYS**2)-2*(N_WAYS)]; //the way to be replaced is the last word in cmp_lru, after all the comparisions, having there the lowest line_addr way LRU 



`elsif LRU

   wire [N_WAYS*NWAY_W -1:0] mru_output, mru_input;
   wire [N_WAYS*NWAY_W -1:0] mru_check; //For checking the MRU line, to initialize it if it wasn't
   wire [N_WAYS*NWAY_W -1:0] mru_cnt; //updates the MRU line, the way used will be the highest value, while the others are decremented
   wire [N_WAYS -1:0]        mru_cnt_way_en; //Checks if decrementation should be done, if there isn't any way that received an hit while already being highest priority
   wire                      mru_cnt_en = &mru_cnt_way_en; //checks if the hit was in a way that wasn't the highest priority
   wire [NWAY_W -1:0]        mru_hit_min [N_WAYS :0];
   wire [N_WAYS -1:0]        lru_sel; //selects the way to be replaced, using the LSB of each Way's section
   assign mru_hit_min [0] [NWAY_W -1:0] = {NWAY_W{1'b0}};
   genvar                    i;
   generate
      for (i = 0; i < N_WAYS; i=i+1)
	begin
	   assign mru_check [(i+1)*NWAY_W -1: i*NWAY_W] = (|mru_output)? mru_output [(i+1)*NWAY_W -1: i*NWAY_W] : i; //verifies if the mru line has been initialized (if any bit in mru_output is HIGH), otherwise applies the priority values, where the lower way line_addres are the least recent (lesser priority)
	   assign mru_cnt_way_en [i] = ~(&(mru_check [NWAY_W*(i+1) -1 : i*NWAY_W]) && way_hit[i]) && (|way_hit); //verifies if there is an hit, and if the hit is the MRU way ({NWAY_{1'b1}} => & MRU = 1,) (to avoid updating during write-misses)
	   
	   assign mru_hit_min [i+1][NWAY_W -1:0] = mru_hit_min[i][NWAY_W-1:0] | ({NWAY_W{way_hit[i]}} & mru_check [(i+1)*NWAY_W -1: i*NWAY_W]); //in case of a write hit, get's the minimum value that can be decreased in mru_cnt, to avoid (subtracting) overflows
	   
	   assign mru_cnt [(i+1)*NWAY_W -1: i*NWAY_W] = (way_hit[i])? (N_WAYS-1) : ((mru_check[(i+1)*NWAY_W -1: i*NWAY_W] > mru_hit_min[N_WAYS][NWAY_W -1:0])? (mru_check [(i+1)*NWAY_W -1: i*NWAY_W] - 1) : mru_check [(i+1)*NWAY_W -1: i*NWAY_W]); //if the way was used, put it's in the highest value, otherwise reduces if the value of the position is higher than the previous value that was hit
	   
	   assign lru_sel [i] =&(~mru_check[(i+1)*NWAY_W -1: i*NWAY_W]); // The way is selected if it's value is 0s; the check is used since itś either the output, or, it this is unintialized, places the LRU as the lowest line_addr (otherwise the first would would be the highest.
	end
   endgenerate
   assign mru_input = (mru_cnt_en)? mru_cnt : mru_output; //If an hit occured, and the way hitted wasn't the MRU, then it updates.
   

   
`elsif TREE_PLRU
   
   wire [N_WAYS -1: 1] t_plru, t_plru_output;
   wire [N_WAYS -1: 0] nway_tree [NWAY_W: 0]; // the order of the way line_addr will be [lower; ...; higher way line_addr], for readable reasons
   wire [N_WAYS -1: 0] tplru_sel;
   genvar              i, j, k;

   // Tree-structure: t_plru[i] = tree's bit i (0 - top, towards bottom of the tree)
   generate      
      for (i = 1; i <= NWAY_W; i = i + 1)
	begin
	   for (j = 0; j < (1<<(i-1)) ; j = j + 1)
	     begin
		assign t_plru [(1<<(i-1))+j] = (t_plru_output[(1<<(i-1))+j] || (|way_hit[N_WAYS-(2*j*(N_WAYS>>i)) -1: N_WAYS-(2*j+1)*(N_WAYS>>i)])) && (~(|way_hit[(N_WAYS-(2*j+1)*(N_WAYS>>i)) -1: N_WAYS-(2*j+2)*(N_WAYS>>i)])); // (t-bit + |way_hit[top_section]) * (~|way_hit[lower_section])
	     end
	end
   endgenerate
   
   // Tree's Encoder (to translate it into selectable way) -- nway_tree will represent the line_addres of the way to be selected, but it's order is inverted to be more readable (check treeplru_sel)
   assign nway_tree [0] = {N_WAYS{1'b1}}; // the first position of the tree's matrix will be all 1s, for the AND logic of the following algorithm work properlly
   generate
      for (i = 1; i <= NWAY_W; i = i + 1)
	begin
	   for (j = 0; j < (1 << (i-1)); j = j + 1)
	     begin
		for (k = 0; k < (N_WAYS >> i); k = k + 1)
		  begin
		     assign nway_tree [i][j*(N_WAYS >> (i-1)) + k] = nway_tree [i-1][j*(N_WAYS >> (i-1)) + k] && ~(t_plru_output [(1 << (i-1)) + j]); // the first half will be the Tree's bit inverted (0 equal Left (upper position)
		     assign nway_tree [i][j*(N_WAYS >> (i-1)) + k + (N_WAYS >> i)] = nway_tree [i-1][j*(N_WAYS >> (i-1)) + k] && t_plru_output [(1 << (i-1)) + j]; //second half of the same Tree's bit (1 equals Right (lower position))
		  end	
	     end
	end 
      // placing the way select wire in the correct order for the onehot-binary encoder
      for (i = 0; i < N_WAYS; i = i + 1)
	begin
	   assign tplru_sel[i] = nway_tree [NWAY_W][N_WAYS - i -1];//the last row of nway_tree has the result of the Tree's encoder
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
      .onehot(bitplru_sel[N_WAYS-1:0]),
`elsif LRU     
      .onehot(lru_sel[N_WAYS-1:0]),
`elsif TREE_PLRU
      .onehot(tplru_sel[N_WAYS-1:0]),
`endif
      .bin(way_select)
      );

   
   //Most Recently Used (MRU) memory	   
   iob_reg_file
     #(
       .ADDR_WIDTH (LINE_OFF_W),
`ifdef BIT_PLRU
       .COL_WIDTH (N_WAYS),
`elsif LRU 		
       .COL_WIDTH (N_WAYS*NWAY_W),
`elsif TREE_PLRU
       .COL_WIDTH (N_WAYS-1),
`endif
       .NUM_COL (1)
       ) 
   mru_memory //simply uses the same format as valid memory
     (
      .clk  (clk          ),
      .rst  (reset        ),
`ifdef TREE_PLRU
      .wdata(t_plru       ),
      .rdata(t_plru_output),
`else
      .wdata(mru_input    ),
      .rdata(mru_output   ),			        

`endif      
      .addr (line_addr    ),
      .en   (write_en     )
      );
   
endmodule



/*------------------*/
/* Cache Controller */
/*------------------*/
//Module responsible for performance measuring, information about the current cache state, and other cache functions (like cache-invalidate)

module cache_controller #(
                          parameter DATA_W = 32,
                          parameter CTRL_CNT_ID = 0, 
                          parameter CTRL_CNT = 1
                          )
   (
    input                       clk,
    input [`CTRL_COUNTER_W-1:0] din, 
    output reg                  invalidate,
    input [`ADDR_W-1:0]         addr,
    output reg [DATA_W-1:0]     dout,
    input                       valid,
    output reg                  ready,
    input                       reset, 
    input [1:0]                 write_state
    );

   generate
      if(CTRL_CNT_ID)
        begin
           
           reg [DATA_W-1:0]             instr_hit_cnt, instr_miss_cnt;
           reg [DATA_W-1:0]             read_hit_cnt, read_miss_cnt, write_hit_cnt, write_miss_cnt;
           reg [DATA_W-1:0]             hit_cnt, miss_cnt;
           reg                          ctrl_counter_reset;

           wire                         ctrl_arst = reset | ctrl_counter_reset;
           
           always @ (posedge clk, posedge ctrl_arst)
             begin 		
	        if (ctrl_arst) 
	          begin
                     hit_cnt  <= {DATA_W{1'b0}};
	             miss_cnt <= {DATA_W{1'b0}};
                     read_hit_cnt  <= {DATA_W{1'b0}};
	             read_miss_cnt <= {DATA_W{1'b0}};
	             write_hit_cnt  <= {DATA_W{1'b0}};
	             write_miss_cnt <= {DATA_W{1'b0}};
                     instr_hit_cnt  <= {DATA_W{1'b0}};
  	             instr_miss_cnt <= {DATA_W{1'b0}};
                  end 
	        else
	          begin
                     if (din == `READ_HIT)
	               begin
		          read_hit_cnt <= read_hit_cnt + 1;
		          hit_cnt <= hit_cnt + 1;	  
	               end
	             else if (din == `WRITE_HIT)
	               begin
		          write_hit_cnt <= write_hit_cnt + 1;
		          hit_cnt <= hit_cnt + 1;
	               end
	             else if (din == `READ_MISS)
	               begin
		          read_miss_cnt <= read_miss_cnt + 1;
		          miss_cnt <= miss_cnt + 1;
	               end
	             else if (din == `WRITE_MISS)
	               begin
		          write_miss_cnt <= write_miss_cnt + 1;
		          miss_cnt <= miss_cnt + 1;
	               end
                     else if (din == `INSTR_HIT)
	               begin
		          instr_hit_cnt <= instr_hit_cnt + 1;
	                  hit_cnt <= hit_cnt + 1; 
                       end
	             else if (din == `INSTR_MISS)
	               begin
		          instr_miss_cnt <= instr_miss_cnt + 1;
                          miss_cnt <= miss_cnt + 1;
                       end  
	             else
	               begin
		          read_hit_cnt <= read_hit_cnt;
		          read_miss_cnt <= read_miss_cnt;
		          write_hit_cnt <= write_hit_cnt;
		          write_miss_cnt <= write_miss_cnt;
		          hit_cnt <= hit_cnt;
		          miss_cnt <= miss_cnt;
                          instr_hit_cnt <= instr_hit_cnt;
		          instr_miss_cnt <= instr_miss_cnt;
	               end
	          end
             end
           
           always @ (posedge clk)
             begin
	        dout <= {DATA_W{1'b0}};
	        invalidate <= 1'b0;
	        ctrl_counter_reset <= 1'b0;
	        ready <= valid; // Sends acknowlege the next clock cycle after request (handshake)               
	        if(valid)
                  if (addr == `ADDR_CACHE_HIT)
	            dout <= hit_cnt;
                  else if (addr == `ADDR_CACHE_MISS)
	            dout <= miss_cnt;
	          else if (addr == `ADDR_CACHE_READ_HIT)
	            dout <= read_hit_cnt;
	          else if (addr == `ADDR_CACHE_READ_MISS)
	            dout <= read_miss_cnt;
	          else if (addr == `ADDR_CACHE_WRITE_HIT)
	            dout <= write_hit_cnt;
	          else if (addr == `ADDR_CACHE_WRITE_MISS)
	            dout <= write_miss_cnt;
	          else if (addr == `ADDR_RESET_COUNTER)
	            ctrl_counter_reset <= 1'b1;
	          else if (addr == `ADDR_CACHE_INVALIDATE)
	            invalidate <= 1'b1;	
	          else if (addr == `ADDR_BUFFER_EMPTY)
                    dout <= write_state[0];
                  else if (addr == `ADDR_BUFFER_FULL)
                    dout <= write_state[1];
                  else if (addr == `ADDR_INSTR_HIT)
                    dout <= instr_hit_cnt;
                  else if (addr == `ADDR_INSTR_MISS)
                    dout <= instr_hit_cnt;
	     end
        end  
      else
        if(CTRL_CNT)
          begin
             
             reg [DATA_W-1:0]             read_hit_cnt, read_miss_cnt, write_hit_cnt, write_miss_cnt;
             reg [DATA_W-1:0]             hit_cnt, miss_cnt;
             reg                          ctrl_counter_reset;

             wire                         ctrl_arst = reset| ctrl_counter_reset;
             
             always @ (posedge clk, posedge ctrl_arst)
               begin 		
	          if (ctrl_arst) 
	            begin
                       hit_cnt  <= {DATA_W{1'b0}};
	               miss_cnt <= {DATA_W{1'b0}};
                       read_hit_cnt  <= {DATA_W{1'b0}};
	               read_miss_cnt <= {DATA_W{1'b0}};
	               write_hit_cnt  <= {DATA_W{1'b0}};
	               write_miss_cnt <= {DATA_W{1'b0}};
                    end 
	          else
	            begin
                       if (din == `READ_HIT)
	                 begin
		            read_hit_cnt <= read_hit_cnt + 1;
		            hit_cnt <= hit_cnt + 1;	  
	                 end
	               else if (din == `WRITE_HIT)
	                 begin
		            write_hit_cnt <= write_hit_cnt + 1;
		            hit_cnt <= hit_cnt + 1;
	                 end
	               else if (din == `READ_MISS)
	                 begin
		            read_miss_cnt <= read_miss_cnt + 1;
		            miss_cnt <= miss_cnt + 1;
	                 end
	               else if (din == `WRITE_MISS)
	                 begin
		            write_miss_cnt <= write_miss_cnt + 1;
		            miss_cnt <= miss_cnt + 1;
	                 end
	               else
	                 begin
		            read_hit_cnt <= read_hit_cnt;
		            read_miss_cnt <= read_miss_cnt;
		            write_hit_cnt <= write_hit_cnt;
		            write_miss_cnt <= write_miss_cnt;
		            hit_cnt <= hit_cnt;
		            miss_cnt <= miss_cnt;
	                 end
	            end // else: !if(ctrl_arst)   
               end // always @ (posedge clk, posedge ctrl_arst)
             
             always @ (posedge clk)
               begin
	          dout <= {DATA_W{1'b0}};
	          invalidate <= 1'b0;
	          ctrl_counter_reset <= 1'b0;
	          ready <= valid; // Sends acknowlege the next clock cycle after request (handshake)               
	          if(valid)
                    if (addr == `ADDR_CACHE_HIT)
	              dout <= hit_cnt;
                    else if (addr == `ADDR_CACHE_MISS)
	              dout <= miss_cnt;
	            else if (addr == `ADDR_CACHE_READ_HIT)
	              dout <= read_hit_cnt;
	            else if (addr == `ADDR_CACHE_READ_MISS)
	              dout <= read_miss_cnt;
	            else if (addr == `ADDR_CACHE_WRITE_HIT)
	              dout <= write_hit_cnt;
	            else if (addr == `ADDR_CACHE_WRITE_MISS)
	              dout <= write_miss_cnt;
	            else if (addr == `ADDR_RESET_COUNTER)
	              ctrl_counter_reset <= 1'b1;
	            else if (addr == `ADDR_CACHE_INVALIDATE)
	              invalidate <= 1'b1;	
	            else if (addr == `ADDR_BUFFER_EMPTY)
                      dout <= write_state[0];
                    else if (addr == `ADDR_BUFFER_FULL)
                      dout <= write_state[1];   
               end // always @ (posedge clk)
          end // if (CTRL_CNT)
        else
          begin
             
             always @ (posedge clk)
               begin
	          dout <= {DATA_W{1'b0}};
	          invalidate <= 1'b0;
	          ready <= valid; // Sends acknowlege the next clock cycle after request (handshake)               
	          if(valid)
	            if (addr == `ADDR_CACHE_INVALIDATE)
	              invalidate <= 1'b1;	
	            else if (addr == `ADDR_BUFFER_EMPTY)
                      dout <= write_state[0];
                    else if (addr == `ADDR_BUFFER_FULL)
                      dout <= write_state[1];         
               end // always @ (posedge clk)
          end // else: !if(CTRL_CNT)  
   endgenerate                
   
endmodule // cache_controller
