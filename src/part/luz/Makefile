CFLAGS=-Wall
MKPEF=../spindle/mkpef
PEF2PRG=../spindle/pef2prg

all:			part.pef part.prg

effect.efo:		effect.s
			xa -o $@ $<

part.pef:		effect.efo giphy34.prg
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^
