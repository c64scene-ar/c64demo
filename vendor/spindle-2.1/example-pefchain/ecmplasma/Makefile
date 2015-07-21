CFLAGS=-Wall
LDFLAGS=-lm
XA=xa
MKPEF=../../spindle/mkpef
PEF2PRG=../../spindle/pef2prg

all:			ecmplasma.pef ecmplasma.prg

effect.efo:		effect.s sine.bin
			xa -o $@ $<

ecmplasma.pef:		effect.efo font.bin
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $<

font.bin:		mkfont
			./mkfont >$@

sine.bin:		mksine
			./mksine >$@
