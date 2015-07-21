MKPEF=../../spindle/mkpef
PEF2PRG=../../spindle/pef2prg

all:		music.pef music.prg

install.efo:	install.s
		xa -o $@ $<

music.pef:	install.efo music.bin
		${MKPEF} -o $@ $^

%.prg:		%.pef
		${PEF2PRG} -o $@ $<

music.bin:	music.sid
		dd if=$< of=$@ bs=1 skip=124
