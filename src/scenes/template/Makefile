KICKASS_PATH=../../../vendor/KickAss.jar
SPINDLE_DIR=../../../vendor/spindle-1.0/spindle
MKPEF=$(SPINDLE_DIR)/mkpef
PEF2PRG=$(SPINDLE_DIR)/pef2prg

SCENE=scene_template

SOURCES=$(wildcard *.asm)

all: $(SCENE).pef $(SCENE).prg

$(SCENE).efo: main.asm $(SOURCES)
	java -jar $(KICKASS_PATH) $< -o $@ -binfile -symbolfile

$(SCENE).pef: $(SCENE).efo
	${MKPEF} -o $@ $^

%.prg: %.pef
	${PEF2PRG} -o $@ $<

clean:
	@rm -f $(SCENE).* main.sym

.PHONY: clean
