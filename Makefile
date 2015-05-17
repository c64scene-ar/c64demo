SRC_DIR=src
BIN_DIR=bin

SOURCES=$(wildcard $(SRC_DIR)/*.asm $(SRC_DIR)/**/*.asm)
SYMBOLS=$(patsubst %.asm,%.sym,$(SOURCES))
PRG=$(BIN_DIR)/demo.prg
CT=$(SRC_DIR)/res/demo.ct
SID=$(patsubst %.ct,%.sid,$(CT))

$(PRG): $(SRC_DIR)/index.asm $(SOURCES)
	java -jar vendor/KickAss/KickAss.jar $< -o $@ -libdir $(SRC_DIR)/ -showmem -symbolfile

sid: $(SID)
$(SID): $(CT)
	vendor/ct2util sid $< -o $@

run: $(PRG) $(SID)
	x64 $(PRG)

clean:
	@rm -f $(PRG) $(SYMBOLS)

.PHONY: run sid clean
