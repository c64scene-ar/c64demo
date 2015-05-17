SRC_DIR=src
BIN_DIR=bin

SOURCES=$(wildcard $(SRC_DIR)/*.asm $(SRC_DIR)/**/*.asm)
SYMBOLS=$(patsubst %.asm,%.sym,$(SOURCES))
BIN=$(BIN_DIR)/demo.prg

KICKASS_PATH=vendor/KickAss/KickAss.jar

$(BIN): $(SRC_DIR)/index.asm $(SOURCES)
	java -jar $(KICKASS_PATH) $< -o $@ -libdir $(SRC_DIR)/ -showmem -symbolfile

run: $(BIN)
	x64 $(BIN)

clean:
	rm -f $(BIN) $(SYMBOLS)

.PHONY: run clean
