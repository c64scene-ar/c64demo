CFLAGS=-Wall
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg

all:			hires.pef hires.prg

hires.efo:		hires.s
			xa -o $@ $<

hires.pef:		hires.efo hires.c64 hires-v.c64
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^

clean: 
			rm -f *.efo *.pef *.prg 

