SPINDLE_DIR=../../../vendor/spindle-1.0/spindle
MKPEF=$(SPINDLE_DIR)/mkpef
PEF2PRG=$(SPINDLE_DIR)/pef2prg
XA=xa

# Variables to be defined on each part Makefile:
#
# Mandatory:
#   - PART: name of part
# Optional:
#   - SRC: list of source files to be compiled with xa
#   - OBJ: list of object files to be compiled into a "part effect" (.pef)

SRC=$(PART).s
OBJ=$(PART).efo

all: $(PART).pef $(PART).prg

$(PART).efo: $(SRC)
	$(XA) -o $@ $^

$(PART).pef: $(OBJ)
	${MKPEF} -o $@ $^

%.prg: %.pef
	${PEF2PRG} -o $@ $^

clean:
	rm -f *.efo *.pef *.prg

run: $(PART).prg
	x64 $<

.PHONY: clean run
