CFLAGS=-Wall
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg


all:			hswitch.pef hswitch.prg


hswitch.efo:		hswitch.s
			xa -o $@ $<

hswitch.pef:		hswitch.efo screen-1.c64 color-1.c64
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^
