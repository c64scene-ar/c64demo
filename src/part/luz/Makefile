CFLAGS=-Wall
LDLIBS=-lm
XA=xa
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg

all:			luz.pef luz.prg

luz.efo:		luz.s 
			xa -o $@ $<

luz.pef:		luz.efo giphy34.gfx
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $<

