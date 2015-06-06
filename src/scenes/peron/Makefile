KICKASS_PATH=../../../vendor/KickAss.jar
SPINDLE_DIR=../../../vendor/spindle-1.0/spindle
MKPEF=$(SPINDLE_DIR)/mkpef
PEF2PRG=$(SPINDLE_DIR)/pef2prg

SOURCES=$(wildcard *.asm)

all: fx.pef fx.prg

fx.efo: index.asm $(SOURCES)
	java -jar $(KICKASS_PATH) $< -o $@ -showmem -symbolfile

fx.pef: fx.efo
	${MKPEF} -o $@ $^

%.prg: %.pef
	${PEF2PRG} -o $@ $<
