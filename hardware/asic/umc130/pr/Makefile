CASE=TC
ROM_DIR=../memory/bootrom
RAM_DIR=../memory/bootram

all:
	cp $(ROM_DIR)/*$(CASE).lib $(RAM_DIR)/*$(CASE).lib .
	./pr.sh
clean:
	rm -rf libscore_work celtic system* timingReports
	rm -f encounter.* *~ *.lib .holdtw.typical_view*
	rm -f .system* .timing* .view_def_*
	rm -rf nanoroute_tmp_237ETo clock_report Clock.ctstch
