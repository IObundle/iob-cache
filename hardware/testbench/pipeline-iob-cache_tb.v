`timescale 1ns/10ps

`include "iob-cache_tb.vh"

module iob_cache_tb;

   parameter cc = 2; //clock-cycle
   parameter AXI_ID_W = 4;
   parameter AXI_ADDR_W=`MEM_ADDR_W;
   parameter AXI_DATA_W=`MEM_DATA_W;
   
   reg clk = 1;
   always #1 clk = ~clk;
   reg reset = 1;
   
   reg [`ADDR_W-1  :$clog2(`DATA_W/8)] addr =0;
   reg [`DATA_W-1:0]                   wdata=0;
   reg [`DATA_W/8-1:0]                 wstrb=0;
   reg                                 valid=0;
   wire [`DATA_W-1:0]                  rdata;
   wire                                ready;
   reg                                 ctrl =0;
   wire                                i_select =0, d_select =0;
   reg [31:0]                          test = 0;
   reg                                 pipe_en = 0;
   
   integer                             i,j;

   initial 
     begin
        
`ifdef VCD
	$dumpfile("uut.vcd");
	$dumpvars();
`endif  
        repeat (5) @(posedge clk);
        reset = 0;
        #10;
        
        $display("\nInitializing Cache testing - check simulation results\n");
        $display("Test 1 - Writing test\n");
        test <= 1;
        valid <= 1;
        addr <= 0;
        wdata <= 0;
        wstrb <= {`DATA_W/8{1'b1}};
        #2;
        
        for (i = 1; i < 10; i = i + 1)
          begin
             //wstrb <= {`DATA_W/8{1'b1}};
             addr <= i;
             wdata <=  i;
             #2
               while (ready == 1'b0)#2;
             
          end // for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
        valid <= 0;
        #80;
        
        $display("Test 2 - Reading Test\n");
        test <= 2;
        addr <= 0;
        wdata <= 2880291038;
        wstrb <= 0;
        valid <= 1;
        #2;
        for (j = 1; j < 10; j = j + 1)
          begin
             addr <= j;
             #2
               while (ready == 1'b0) #2;  
          end // for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
        valid <=0;
        addr <= 0;
        #20;



        $display("Test 3 - Writing (write-hit) test\n");
        test <= 3;
        addr <= 0;
        wdata <= 10;
        wstrb <= {`DATA_W/8{1'b1}};
        valid <= 1;
        // #2;
        // valid <= 0;
        
        #2;
        for (i = 1; i < 11; i = i + 1)
          begin
             addr <= i;
             wdata <=  i + 10;
             #2;
             
             while (ready == 1'b0) #2;
          end // for (i = 0; i < 2**(`ADDR_W-$clog2(`DATA_W/8)); i = i + 1)
        valid <= 0;
        addr <=0;
        #80;
        
        $display("Test 4 - Testing RAW control (r-w-r)\n");
        test <= 4;
        addr <= 0;
        valid <=1;
        wstrb <=0;
        #2;
        while (ready == 1'b0) #2;
        wstrb <= {`DATA_W/8{1'b1}};
        wdata <= 57005;
        #2;
        wstrb <= 0;
        #2
          while (ready == 1'b0) #2;
        valid <= 0;
        #80;
        
        $display("Test 5 - Test Line Replacement with read the last written position\n");
        test <= 5;
        addr <= (2**`WORD_OFF_W)*5-1;
        valid <= 1;
        wstrb <= {`DATA_W/8{1'b1}};
        wdata <= 3735928559;
        #2;
        while (ready == 1'b0) #2;
        valid <= 0;
        wstrb <= 0;
        while (ready == 1'b0) #2;
        valid <= 0;
        #80;



        $display("Test 6 - Testing RAW on different positions (r-w-r)\n");
        test <= 6;
        addr <= 0;
        valid <=1;
        wstrb <=0;
        #20
          wstrb <= {`DATA_W/8{1'b1}};
        wdata <= 23434332205;
        //while (ready == 1'b0) #2;
        #2;
        addr <= 1; //change of addr
        wstrb <= 0;
        #2
          while (ready == 1'b0) #2;
        valid <= 0;
        #80;

       
        $display("Test 7 - Testing cache-invalidate (r-inv-r)\n");
        test <= 7;
        addr <= 0;
        valid <=1;
        wstrb <=0;
        while (ready == 1'b0) #2;
        ctrl <=1;  //ctrl function
        addr <= 10;//invalidate
        valid <=1;
        #2;
        while (ready == 1'b0) #2;
        ctrl <=0;
        addr <=0;
        #80;
        $display("Cache testing completed\n");
        $finish;
     end // initial begin


   
`ifdef AXI
   //AXI connections
 `include "m_axi_wire.vh"   
`else
   //Native connections
   wire [`MEM_ADDR_W-1:0]          mem_addr;
   wire [`MEM_DATA_W-1:0]          mem_wdata, mem_rdata;
   wire [`MEM_N_BYTES-1:0]         mem_wstrb;
   wire                            mem_valid;
   reg                             mem_ready;
`endif  
   
   reg                             cpu_state;

   reg [`ADDR_W-1  :$clog2(`DATA_W/8)] cpu_addr;
   reg [`DATA_W-1:0]                   cpu_wdata;
   reg [`DATA_W/8-1:0]                 cpu_wstrb;
   reg                                 cpu_valid;

   reg [`ADDR_W-1  :$clog2(`DATA_W/8)] cpu_addr_reg;
   reg [`DATA_W-1:0]                   cpu_wdata_reg;
   reg [`DATA_W/8-1:0]                 cpu_wstrb_reg;
   reg                                 cpu_valid_reg;
   
   always @(posedge clk, posedge reset)
     if (reset)
       cpu_state <= 0;
     else
       case(cpu_state)
         1'b0:
           begin
              if (valid)
                cpu_state <= 1'b1;
              else
                cpu_state <= 1'b0;
           end

         1'b1:
           begin
              if (~ready | valid)
                cpu_state<=1'b1;
              else
                cpu_state <= 1'b0;
           end
         default:;

       endcase

   always @(posedge clk)
     begin
        cpu_addr_reg <= cpu_addr;
        cpu_wdata_reg <= cpu_wdata;
        cpu_wstrb_reg <= cpu_wstrb;
        cpu_valid_reg <= cpu_valid;
     end
   
   

   always @*
     begin 
        cpu_valid = cpu_valid;
        cpu_addr = cpu_addr;
        cpu_wdata = cpu_wdata;
        cpu_wstrb = cpu_wstrb;
        case(cpu_state)
          1'b0:
            begin
               cpu_valid = valid;
               cpu_addr = addr;
               cpu_wdata = wdata;
               cpu_wstrb = wstrb;
            end
          1'b1:
            if (ready)
              begin
                 cpu_valid = valid;
                 cpu_addr = addr;
                 cpu_wdata = wdata;
                 cpu_wstrb = wstrb;
              end
            else
              begin
                 cpu_valid = cpu_valid_reg;
                 cpu_addr = cpu_addr_reg;
                 cpu_wdata = cpu_wdata_reg;
                 cpu_wstrb = cpu_wstrb_reg;
              end // else: !if(ready)
          default:;
        endcase // case (cpu_state)
     end

   
`ifdef AXI  
   iob_cache_axi 
     #(
       .AXI_ID_W(4),
       .AXI_ADDR_W(`MEM_ADDR_W),
       .AXI_DATA_W(`MEM_DATA_W),
       .FE_ADDR_W(`ADDR_W),
       .FE_DATA_W(`DATA_W),
       .N_WAYS(`N_WAYS),
       .LINE_OFF_W(`LINE_OFF_W),
       .WORD_OFF_W(`WORD_OFF_W),
       .BE_ADDR_W(`MEM_ADDR_W),
       .BE_DATA_W(`MEM_DATA_W),
       .REP_POLICY(`REP_POLICY),
       .CTRL_CACHE(1),
       .WTBUF_DEPTH_W(`WTBUF_DEPTH_W),
       .WRITE_POL(`WRITE_POL)
       )
   cache 
     (
      .valid (cpu_valid),
      .addr  ({ctrl,cpu_addr}),
      .wstrb (cpu_wstrb),
      .wdata (cpu_wdata),
      .rdata (rdata),
      .ready (ready),

      .force_inv_in(1'b0),
      .force_inv_out(),
      .wtb_empty_in(1'b1),
      .wtb_empty_out(),
      
 `include "m_axi_portmap.vh"
      .clk (clk),
      .reset (reset)      
      );

   
`else
   
   iob_cache 
     #(
       .FE_ADDR_W(`ADDR_W),
       .FE_DATA_W(`DATA_W),
       .N_WAYS(`N_WAYS),
       .LINE_OFF_W(`LINE_OFF_W),
       .WORD_OFF_W(`WORD_OFF_W),
       .BE_ADDR_W(`MEM_ADDR_W),
       .BE_DATA_W(`MEM_DATA_W),
       .REP_POLICY(`REP_POLICY),
       .CTRL_CACHE(1),
       .WTBUF_DEPTH_W(`WTBUF_DEPTH_W),
       .WRITE_POL (`WRITE_POL),
       .AXI_ID_W (4),
       .AXI_ADDR_W (`ADDR_W),
       .AXI_DATA_W (`DATA_W),
       )
   cache 
     (
      .clk (clk),
      .reset (reset),
      .wdata (cpu_wdata),
      .addr  ({ctrl,cpu_addr}),
      .wstrb (cpu_wstrb),
      .rdata (rdata),
      .valid (cpu_valid),
      .ready (ready),
      //CTRL_IO
      .force_inv_in(1'b0),
      .force_inv_out(),
      .wtb_empty_in(1'b1),
      .wtb_empty_out(),
      //
      // NATIVE MEMORY INTERFACE
      //
      .mem_addr(mem_addr),
      .mem_wdata(mem_wdata),
      .mem_wstrb(mem_wstrb),
      .mem_rdata(mem_rdata),
      .mem_valid(mem_valid),
      .mem_ready(mem_ready)
      );
   
   
`endif
   
   
   
`ifdef AXI  
   axi_ram 
     #(
       .ID_WIDTH(AXI_ID_W),
       .DATA_WIDTH (`MEM_DATA_W),
       .ADDR_WIDTH (`MEM_ADDR_W)
       )
   axi_ram
     (
 `include "s_axi_portmap.vh"
      .clk            (clk),
      .rst            (reset)
      ); 

`else

   iob_sp_ram_be 
     #(
       .NUM_COL(`MEM_N_BYTES),
       .COL_W(8),
       .ADDR_W(`MEM_ADDR_W-2)
                   )
   native_ram
     (
      .clk(clk),
      .en  (mem_valid),
      .we  (mem_wstrb),
      .addr(mem_addr[`MEM_ADDR_W-1:$clog2(`MEM_DATA_W/8)]),
      .dout(mem_rdata),
      .din (mem_wdata)
      );

   always @(posedge clk)
     mem_ready <= mem_valid;
   
   
`endif

endmodule // iob_cache_tb


