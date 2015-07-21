CFLAGS=-Wall -O3
LDFLAGS=

all:		mkheader mkpef pef2prg pefchain spin

mkpef:		mkpef.c common.h pef.h
		gcc ${CFLAGS} -o $@ $<

pef2prg:	pef2prg.c common.h pef.h prgloader.h
		gcc ${CFLAGS} -o $@ $<

%.prg:		%.s
		xa -o $@ $<

%.bin:		%.s
		xa -o $@ $<

prgloader.prg:	prgloader.s commonsetup.bin
		xa -o $@ $<

stage1.prg:	stage1.s
		xa -o $@ $<

pefchain.o:	pefchain.c common.h pef.h commonsetup.h pack.h disk.h
		gcc ${CFLAGS} -c -o $@ $<

pack.o:		pack.c disk.h pack.h
		gcc ${CFLAGS} -c -o $@ $<

disk.o:		disk.c disk.h datatables.h
		gcc ${CFLAGS} -c -o $@ $<

spin.o:		spin.c common.h disk.h pack.h

pefchain:	pefchain.o pack.o disk.o

spin:		spin.o pack.o disk.o

datatables.h:	stage1.prg drivecode.bin
		./mkheader >$@ $^

commonsetup.h:	commonsetup.bin
		./mkheader >$@ $^

prgloader.h:	prgloader.prg
		./mkheader >$@ $^

winspin.exe:	spin.c pack.c disk.c compat/err.c
		i586-mingw32msvc-gcc -Wl,--stack,5000000 -Wall -O3 -idirafter compat -o $@ $^
