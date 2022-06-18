#
# This file is included in BUILD_DIR/sim/Makefile
#

test: iob-cache-clean-testlog $(TEST_LIST)
	diff -q test.log test.expected

# choose top module file for iob or axi back-end interface 

TOP_ROOT=../vsrc/top/$(TOP_MODULE)
TOP_CURR=../vsrc/top/$(TOP_MODULE).v
VSRC+=$(TOP_CURR)

$(TOP_CURR):
ifeq ($(BE_IF),axi)
	if [ ! -f $(TOP_CURR) ]; then cp $(TOP_ROOT)_axi.v $(TOP_CURR); elif [ "`diff -q $(TOP_ROOT)_axi.v $(TOP_CURR)`" ]; then cp $(TOP_ROOT)_axi.v $(TOP_CURR); fi
else
	if [ ! -f $(TOP_CURR) ]; then cp $(TOP_ROOT)_iob.v $(TOP_CURR); elif [ "`diff -q $(TOP_ROOT)_iob.v $(TOP_CURR)`" ]; then cp $(TOP_ROOT)_iob.v $(TOP_CURR); fi
endif

.PHONY: test $(TOP_CURR)
