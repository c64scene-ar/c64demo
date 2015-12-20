CFLAGS=-Wall
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg


all:			pet.pef pet.prg


pet.efo:		pet.s
			xa -o $@ $<

pet.pef:		pet.efo screen-0.c64 color-0.c64
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^
