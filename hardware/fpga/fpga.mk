#
# This file is included in BUILD_DIR/fpga/Makefile
#

include ../hw-comp.mk

ifeq ($(BE_IF),axi)
DEFINE=AXI
else
DEFINE=IOB
endif

