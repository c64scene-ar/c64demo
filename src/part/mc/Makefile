CFLAGS=-Wall
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg

all:			mc.pef mc.prg

mc.efo:		mc.s
			xa -o $@ $<

mc.pef:		mc.efo mc.c64 mc-v.c64 mc-c.c64
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^

clean: 
			rm -f *.efo *.pef *.prg 

