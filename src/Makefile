include common.mk

DISK_IMG=demo.d64

all: $(DISK_IMG)

$(DISK_IMG): script dirart.txt part.dir
	${PEFCHAIN} ${PEFFLAGS} -o $@ -a dirart.txt -d 2 $<
	@echo

part.dir: $(wildcard part/**/*.pef)
	make -C $(basename $@)

clean:
	rm -f $(DISK_IMG)
	make -C part clean

run: $(DISK_IMG)
	x64 $(DISK_IMG)

.PHONY: part.dir clean run
