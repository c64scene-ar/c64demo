KICKASS_PATH=../../../vendor/KickAss.jar
SPINDLE_DIR=../../../vendor/spindle-1.0/spindle
MKPEF=$(SPINDLE_DIR)/mkpef
PEF2PRG=$(SPINDLE_DIR)/pef2prg

SOURCES=$(wildcard *.asm)

all: scene_peron.pef scene_peron.prg

scene_peron.efo: index.asm $(SOURCES)
	java -jar $(KICKASS_PATH) $< -o $@ -binfile -showmem -symbolfile

scene_peron.pef: scene_peron.efo
	${MKPEF} -o $@ $^

%.prg: %.pef
	${PEF2PRG} -o $@ $<
