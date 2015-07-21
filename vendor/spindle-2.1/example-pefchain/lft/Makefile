CFLAGS=-Wall -std=c99
LDLIBS=-lm
XA=xa
MKPEF=../../spindle/mkpef
PEF2PRG=../../spindle/pef2prg

all:		lft.pef lft.prg

bitmap1.bin:	maptest
		./maptest

effect.efo:	effect.s sine.i logo.i
		${XA} -o $@ $<

lft.pef:	bitmap1.bin effect.efo
		${MKPEF} -o $@ effect.efo bitmap?.bin speedcode?.bin

%.prg:		%.pef
		${PEF2PRG} -o $@ $<

sine.i:		mksine
		./mksine >$@

logo.i:		mklogo
		./mklogo >$@
