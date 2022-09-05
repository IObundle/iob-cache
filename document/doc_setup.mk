# (c) 2022-Present IObundle, Lda, all rights reserved
#
# This makefile segment is used at setup-time in $(LIB_DIR)/Makefile
#
# It copies all hardware header and source files to $(BUILD_DIR)/doc
#
#


# VERSION FILE
# create and copy core version header files
SRC+=$(BUILD_DOC_DIR)/tsrc/iob_cache_version.tex
$(BUILD_DOC_DIR)/tsrc/iob_cache_version.tex:
	$(LIB_DIR)/software/python/version.py -t $(CACHE_DIR)
	mv iob_cache_version.tex $(BUILD_DOC_DIR)/tsrc
