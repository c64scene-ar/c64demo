CFLAGS=-Wall
LDLIBS=-lm
XA=xa
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg

all:			vborder.pef vborder.prg

vborder.efo:		vborder.s 
			xa -o $@ $<

vborder.pef:		vborder.efo pungas.c64 pungas-v.c64 pungas-c.c64
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $<

