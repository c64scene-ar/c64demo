CFLAGS=-Wall

all:		mkheader mkpef pef2prg pefchain

mkpef:		mkpef.c common.h
		gcc ${CFLAGS} -o $@ $<

pef2prg:	pef2prg.c common.h prgloader.h
		gcc ${CFLAGS} -o $@ $<

%.prg:		%.s
		xa -o $@ $<

%.bin:		%.s
		xa -o $@ $<

decruncher.bin:	decruncher.s blankfiller.bin
		xa -o $@ $<

prgloader.prg:	prgloader.s commonsetup.bin
		xa -o $@ $<

pefchain.o:	pefchain.c common.h pefchain.h commonsetup.h
		gcc ${CFLAGS} -c -o $@ $<

pack.o:		pack.c pefchain.h
		gcc ${CFLAGS} -c -o $@ $<

disk.o:		disk.c pefchain.h datatables.h
		gcc ${CFLAGS} -c -o $@ $<

pefchain:	pefchain.o pack.o disk.o

datatables.h:	stage1.prg drivecode.bin decruncher.bin
		./mkheader >$@ $^

commonsetup.h:	commonsetup.bin
		./mkheader >$@ $^

prgloader.h:	prgloader.prg
		./mkheader >$@ $^
