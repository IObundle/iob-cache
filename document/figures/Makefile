CC = libreoffice
CFLAGS = --headless --convert-to pdf
LO_RUNNING = $(shell pgrep libreoffice)
OBJS = $(patsubst %.odg,%.pdf,$(wildcard *.odg))

all: $(OBJS) $(TD_FIGS)

ifeq ($(LO_RUNNING), )
$(OBJS): %.pdf : %.odg
	$(CC) $(CFLAGS) $<
else 	
$(error LibreOffice is running. Close it before proceeding.)
endif

$(TD_FIGS): %.pdf : ../wavedrom/%.drom
	npx wavedrom-cli -i $< -s temp.svg
	inkscape --file temp.svg --export-pdf $@
	rm -f temp.svg

clean:
	@rm -f *.pdf *~ $(TD_FIGS)

.PHONY: all clean

