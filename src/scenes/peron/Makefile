CFLAGS=-Wall
MKPEF= ../../../vendor/spindle-1.0/spindle/mkpef
PEF2PRG=../../../vendor/spindle-1.0/spindle/pef2prg

all:			peron.pef peron.prg

peron.efo:		peron.asm
			xa -o $@ $<

peron.pef:		peron.efo # Add more files here...
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^
