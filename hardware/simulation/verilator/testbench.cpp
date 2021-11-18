#include <verilated.h>
#include <verilated_vcd_c.h>
#include <iostream>

#include "obj_dir/Viob_cache.h"

int main(int argc, char** argv) {
    std::cout << std::endl << "Iob_cache simulation start" << std::endl;

    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Viob_cache* tb = new Viob_cache;
    VerilatedVcdC* tfp = new VerilatedVcdC;

    tb->trace(tfp,99); // Trace 99 levels of hierarchy
    tb->reset = 0;

    tfp->open("vcd.vcd");

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
        tfp->dump(main_time);
        main_time++;

        // Stop after a set time, since otherwise the current design would simulate forever
        if(main_time > 100){
            break;
        }
    }

    tb->final();
    tfp->dump(main_time);

    tfp->close();

    std::cout << "Generated vcd file" << std::endl;

    delete tb;
    delete tfp;

    std::cout << "Iob_cache simulation end" << std::endl << std::endl;

    return 0;
}