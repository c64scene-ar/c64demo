KICKASS_PATH=../../../vendor/KickAss.jar
SPINDLE_DIR=../../../vendor/spindle-1.0/spindle
MKPEF=$(SPINDLE_DIR)/mkpef
PEF2PRG=$(SPINDLE_DIR)/pef2prg

SCENE=scene_peron

SOURCES=$(wildcard *.asm)

all: $(SCENE).pef $(SCENE).prg

$(SCENE).efo: index.asm $(SOURCES)
	java -jar $(KICKASS_PATH) $< -o $@ -binfile -symbolfile

$(SCENE).pef: $(SCENE).efo
	${MKPEF} -o $@ $^

%.prg: %.pef
	${PEF2PRG} -o $@ $<

clean:
	@rm -f $(SCENE).* index.sym

.PHONY: clean
