CFLAGS=-Wall
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg

all:			fli.pef fli.prg

fli.efo:		fli.s
			xa -o $@ $<

fli.pef:		fli.efo fli.c64 fli-v.c64 fli-c.c64
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^

clean: 
			rm -f *.efo *.pef *.prg 

