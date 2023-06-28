#include "Viob_cache_sim_wrapper.h"
#include <fstream>
#include <iostream>
#include <verilated.h>

#if (VM_TRACE == 1) // If verilator was invoked with --trace
#include <verilated_vcd_c.h>
#endif

#define MAX_SIM_TIME 120

vluint64_t main_time = 0;
vluint64_t posedge_cnt = 0;
vluint32_t RW = 0, iw = 0, ir = 0, itest = 0;

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

int main(int argc, char **argv) {

  Verilated::commandArgs(argc, argv); // Init verilator context
  Viob_cache_sim_wrapper *dut = new Viob_cache_sim_wrapper; // Create DUT object

#if (VM_TRACE == 1)
  Verilated::traceEverOn(true);           // Enable tracing
  VerilatedVcdC *tfp = new VerilatedVcdC; // Create tracing object
  dut->trace(tfp, 99);                    // Trace 99 levels of hierarchy
  tfp->open("uut.vcd");                   // Open tracing file
#endif

  dut->clk_i = 1;
  dut->arst_i = 0;
  while (main_time < MAX_SIM_TIME) {
    dut->clk_i = !dut->clk_i;
    dut->arst_i = (main_time >= 1 && main_time <= 8) ? 1 : 0;
    dut->eval();

    if (dut->clk_i == 1) {
      posedge_cnt++;

      // if(posedge_cnt == 7) VL_PRINTF("IOb-Cache Version: %d\n",
      // cache_version());

      if ((posedge_cnt >= 8) && (iw < 5)) {
        if (posedge_cnt == 8)
          VL_PRINTF("Test 1: Writing Test\n");
        RW = 0;
        dut->avalid = 1;
        dut->wstrb = 15;
        dut->addr = iw;
        dut->wdata = iw * 3;
      }

      if ((posedge_cnt >= 30) && (ir < 5)) {
        if (posedge_cnt == 30)
          VL_PRINTF("Test 2: Reading Test\n");
        RW = 1;
        dut->avalid = 1;
        dut->wstrb = 0;
        dut->addr = ir;
      }

      if (dut->ack) {
        dut->avalid = 0;
        if ((posedge_cnt >= 8) && (posedge_cnt < 30))
          iw++;
        else if (posedge_cnt >= 30)
          ir++;
      }

      if ((RW == 1) && dut->ack && (itest < 5)) {
        if (dut->rdata == itest * 3) {
          VL_PRINTF("\tReading rdata=0x%x at addr=0x%x: PASSED\n", dut->rdata,
                    itest);
        } else {
          VL_PRINTF("\tReading rdata=0x%x at addr=0x%x: FAILED\n", dut->rdata,
                    itest);
          std::ofstream log_file;
          log_file.open("test.log");
          log_file << "Test failed!" << std::endl;
          log_file.close();
          exit(EXIT_FAILURE);
        }
        itest++;
      }
    }

#if (VM_TRACE == 1)
    tfp->dump(main_time); // Dump values into tracing file
#endif
    main_time++;
  }

  dut->final();

#if (VM_TRACE == 1)
  tfp->dump(main_time); // Dump last values
  tfp->close();         // Close tracing file
  std::cout << "Generated vcd file" << std::endl;
  delete tfp;
#endif

  delete dut;

  std::ofstream log_file;
  log_file.open("test.log");
  log_file << "Test passed!" << std::endl;
  log_file.close();
  exit(EXIT_SUCCESS);
}
