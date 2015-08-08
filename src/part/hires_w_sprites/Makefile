CFLAGS=-Wall
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg

all:			hires_s.pef hires_s.prg

hires_s.efo:		hires_s.s
			xa -o $@ $<

hires_s.pef:		hires_s.efo hires_s.c64 hires_s-v.c64 hires_s-s.c64
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^

clean: 
			rm -f *.efo *.pef *.prg 

