CACHE_DIR:=../../../..

include ../../asic.mk

RTL_COMPILER:=source /opt/ic_tools/init/init-rc14_25_hf000

run: $(TOP_MODULE)_synth.v

$(TOP_MODULE)_synth.v: $(VHDR) $(VSRC)
	echo "set INCLUDE [list $(INCLUDE)]" > inc.tcl
	echo "set DEFINE [list $(DEFINE)]" > defs.tcl
	echo "set VSRC [glob $(VSRC)]" > vsrc.tcl
	echo "set TOP_MODULE $(TOP_MODULE)" > top_module.tcl
	$(RTL_COMPILER) && echo "quit" | rc -files inc.tcl -files defs.tcl -files vsrc.tcl -files top_module.tcl -files synscript.tcl
	echo "quit"

clean:
	@rm -rf *~ *.hex *.txt rc.cmd* rc.* fv libscore_work *.sdc *.v *.h *.lib *.db
	@find *.tcl -type f -not -name synscript.tcl -not -name powscript.tcl -delete

.PHONY: run clean
