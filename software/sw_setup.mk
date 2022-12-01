# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment lists all software header and source files 
#
# It is included in submodules/LIB/Makefile for populating the
# build directory
#

ifeq ($(filter CACHE, $(SW_MODULES)),)

#add itself to SW_MODULES list
SW_MODULES+=CACHE


endif
