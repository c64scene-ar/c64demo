CFLAGS=-Wall
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg


all:			pet.pef pet.prg

pet.efo:		pet.s
			xa -o $@ $<

pet.pef:		pet.efo parser/split/*c64 music.bin
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^

music.bin: TURRO1.sid
	   dd if=$< of=$@ bs=1 skip=124
