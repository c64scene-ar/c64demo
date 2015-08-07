CFLAGS=-Wall
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg


all:			part.pef part.prg


effect.efo:		effect.s
			xa -o $@ $<

part.pef:		effect.efo # Add more files here...
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^
