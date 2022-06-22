#include <verilated.h>
#include <iostream>
#include "Viob_cache_wrapper.h"

#if (VM_TRACE == 1)    //If verilator was invoked with --trace
#include <verilated_vcd_c.h>
#endif

#define MAX_SIM_TIME 100

vluint64_t main_time = 0;
vluint64_t posedge_cnt=0;
vluint32_t RW=0, iw=0, ir=0, itest=0;

double sc_time_stamp () {   //Called by $time in Verilog
    return main_time;		
}

int main(int argc, char** argv) {
    std::cout << std::endl << "Iob_cache simulation start" << std::endl;
    Verilated::commandArgs(argc, argv);   //Init verilator context
    Viob_cache_wrapper* dut = new Viob_cache_wrapper; //Create DUT object

#if (VM_TRACE == 1)
    Verilated::traceEverOn(true);   //Enable tracing
    VerilatedVcdC* tfp = new VerilatedVcdC;     //Create tracing object
    dut->trace(tfp,99);    //Trace 99 levels of hierarchy
    tfp->open("uut.vcd");  //Open tracing file
#endif

    dut->clk=1; dut->reset=0;    
    while (main_time < MAX_SIM_TIME) {
        dut->clk=!dut->clk;  
        dut->reset=(main_time > 1 && main_time < 8) ? 1 : 0; 	
        dut->eval();

        if(dut->clk == 1) {
	  posedge_cnt++; 

	  //if(posedge_cnt == 7) VL_PRINTF("IOb-Cache Version: %d\n", cache_version());
	  
	  if((posedge_cnt >= 8) && (iw < 5)) {
	     if(posedge_cnt == 8) VL_PRINTF("Test 1: Writing Test\n");
             RW=0;
             dut->req=1;
             dut->wstrb=15;
             dut->addr=iw;
	     dut->wdata=iw*3;
          }

	  if((posedge_cnt >= 24) && (ir < 5)){
	     if(posedge_cnt == 24) VL_PRINTF("Test 2: Reading Test\n");
             RW=1;
	     dut->req=1;
             dut->wstrb=0;
	     dut->addr=ir;
	  }	
	  
          if(dut->ack) {
	     dut->req=0; 
	     if ((posedge_cnt >= 8) && (posedge_cnt < 24)) iw++;
	     else if (posedge_cnt >= 24) ir++;		      
          }
	
	  if((RW==1) && dut->ack && (itest < 5)){
	    (dut->rdata == itest*3) ? VL_PRINTF("\tReading rdata=0x%x at addr=0x%x: PASSED\n",dut->rdata,itest) : VL_PRINTF("\tReading rdata=0x%x at addr=0x%x: FAILED\n",dut->rdata,itest);
	     itest++;				      
	  }
	}
	
#if (VM_TRACE == 1)
	tfp->dump(main_time); //Dump values into tracing file
#endif
        main_time++;
    }

    dut->final();
    
#if (VM_TRACE == 1)
    tfp->dump(main_time); //Dump last values
    tfp->close(); //Close tracing file
    std::cout << "Generated vcd file" << std::endl;
    delete tfp;
#endif
    
    delete dut;

    std::cout << "Iob_cache simulation end" << std::endl << std::endl;

    exit(EXIT_SUCCESS);
}
