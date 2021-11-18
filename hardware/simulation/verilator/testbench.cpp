#include <verilated.h>
#include <verilated_vcd_c.h>
#include <iostream>

#include "obj_dir/Viob_cache.h"

int main(int argc, char** argv) {
    std::cout << std::endl << "Iob_cache simulation start" << std::endl;

    // Init verilator context and enable tracing
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Viob_cache* tb = new Viob_cache; // Create UUT
    VerilatedVcdC* tfp = new VerilatedVcdC; // Create tracing object

    tb->trace(tfp,99); // Trace 99 levels of hierarchy
    tfp->open("vcd.vcd"); // Open tracing file

    tb->reset = 0; // Init wire to initial value

    int main_time = 0;
    while (!Verilated::gotFinish()) {
        if (main_time > 10) {
            tb->reset = 1;
        }
        if ((main_time % 10) == 1) {
            tb->clk = 1;
        }
        if ((main_time % 10) == 6) {
            tb->clk = 0;
        }
        tb->eval();
        tfp->dump(main_time); // Dump values into tracing file
        main_time++;

        // Stop after a set time, since otherwise the current design would simulate forever
        if(main_time > 100){
            break;
        }
    }

    tb->final();
    tfp->dump(main_time); // Dump last values

    tfp->close(); // Close tracing file

    std::cout << "Generated vcd file" << std::endl;

    delete tb;
    delete tfp;

    std::cout << "Iob_cache simulation end" << std::endl << std::endl;

    return 0;
}
