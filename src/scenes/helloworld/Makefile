CFLAGS=-Wall
MKPEF= ../../../vendor/spindle-1.0/spindle/mkpef
PEF2PRG=../../../vendor/spindle-1.0/spindle/pef2prg

all:			part.pef part.prg

hello.efo:		hello.asm
			xa -o $@ $<

part.pef:		hello.efo # Add more files here...
			${MKPEF} -o $@ $^

%.prg:			%.pef
			${PEF2PRG} -o $@ $^
