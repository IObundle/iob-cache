VHDR+=iob_gen_if.vh
iob_gen_if.vh: 	$(LIB_DIR)/hardware/include/iob_gen_if.vh
	cp $< $@

AXI_GEN:=$(LIB_DIR)/software/python/axi_gen.py
VHDR+=iob_cache_axi_m_port.vh
iob_cache_axi_m_port.vh:
	$(AXI_GEN) axi_m_port iob_cache_
