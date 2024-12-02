// SPDX-FileCopyrightText: 2024 IObundle
//
// SPDX-License-Identifier: MIT

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
Viob_cache_sim_wrapper *dut;
VerilatedVcdC *tfp;

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

void tick() {
  if (main_time >= MAX_SIM_TIME) {
    throw std::runtime_error(
        "Simulation time exceeded maximum simulation time");
  }
  dut->clk_i = !dut->clk_i;
  dut->eval();
  dut->clk_i = !dut->clk_i;
  dut->eval();
#if (VM_TRACE == 1)
  tfp->dump(main_time); // Dump values into tracing file
#endif
  main_time++;
}

int main(int argc, char **argv) {

  Verilated::commandArgs(argc, argv); // Init verilator context
  dut = new Viob_cache_sim_wrapper;   // Create DUT object

#if (VM_TRACE == 1)
  Verilated::traceEverOn(true); // Enable tracing
  tfp = new VerilatedVcdC;      // Create tracing object
  dut->trace(tfp, 99);          // Trace 99 levels of hierarchy
  tfp->open("uut.vcd");         // Open tracing file
#endif

  dut->clk_i = 0;
  dut->arst_i = 1;

  for (uint32_t i = 0; i < 8; i++) {
    tick();
  }

  dut->arst_i = 0;
  tick();

  for (uint32_t i = 0; i < 5; i++) {
    if (i == 0)
      VL_PRINTF("Test 1: Writing Test\n");
    dut->iob_valid_i = 1;
    dut->iob_wstrb_i = 15;
    dut->iob_addr_i = i;
    dut->iob_wdata_i = i * 3;
    tick();
    while (!dut->iob_ready_o) {
      tick();
    }
  }

  for (uint32_t i = 0; i < 5; i++) {
    if (i == 0)
      VL_PRINTF("Test 2: Reading Test\n");
    dut->iob_valid_i = 1;
    dut->iob_wstrb_i = 0;
    dut->iob_addr_i = i;
    tick();
    while (!dut->iob_rvalid_o) {
      tick();
    }
    if (dut->iob_rdata_o == i * 3) {
      VL_PRINTF("\tReading rdata=0x%x at addr=0x%x: PASSED\n", dut->iob_rdata_o,
                i);
    } else {
      VL_PRINTF("\tReading rdata=0x%x at addr=0x%x: FAILED\n", dut->iob_rdata_o,
                i);
      std::ofstream log_file;
      log_file.open("test.log");
      log_file << "Test failed!" << std::endl;
      log_file.close();
      exit(EXIT_FAILURE);
    }
  }

#if (VM_TRACE == 1)
  tfp->dump(main_time); // Dump values into tracing file
#endif
  main_time++;

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
