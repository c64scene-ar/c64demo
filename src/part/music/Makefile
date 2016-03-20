MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg

all:		music.pef music.prg

install.efo:	install.s
		xa -o $@ $<

music.pef:	install.efo music.bin
		${MKPEF} -o $@ $^

%.prg:		%.pef
		${PEF2PRG} -o $@ $<

music.bin:	uc-yasashisa_ni.sid
		dd if=$< of=$@ bs=1 skip=124
