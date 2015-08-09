CFLAGS=-Wall
MKPEF=../../../vendor/spindle-2.1/spindle/mkpef
PEF2PRG=../../../vendor/spindle-2.1/spindle/pef2prg

PART=sprite

all: $(PART).pef $(PART).prg

$(PART).efo: $(PART).s
	xa -o $@ $<

$(PART).pef: $(PART).efo img.c64
	${MKPEF} -o $@ $^

%.prg: %.pef
	${PEF2PRG} -o $@ $^

clean:
	rm -f *.efo *.pef *.prg

run: $(PART).prg
	x64 $<
