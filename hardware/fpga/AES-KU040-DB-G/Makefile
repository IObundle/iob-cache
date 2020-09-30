CACHE_DIR:=../../..

include ../fpga.mk

# work-around for http://svn.clifford.at/handicraft/2016/vivadosig11
export RDI_VERBOSE = False

synth: *.xdc $(VSRC)	
	rm -f $@.log
	vivado -nojournal -log $@.log -mode batch -source synth.tcl -tclargs "$(INCLUDE)" "$(VSRC)"
	-grep -B4 -A10 'CLB LUTs' vivado.log
	-grep -B1 -A9 ^Slack vivado.log && echo

GARBAGE:=.Xil/ *.map *. *~ synth_*.mmi synth_*.bit synth_system*.v *.vcd *_tb \
table.txt tab_*/ *webtalk* *.jou *.log .log xelab.* xsim[._]* xvlog.* uart_loader *.ltx fsm_encoding.os *.txt

fpga-clean:
	rm -rf $(GARBAGE)

.PHONY: load compile fpga-clean
