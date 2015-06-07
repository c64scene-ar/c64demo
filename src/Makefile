PEFCHAIN=../vendor/spindle-1.0/spindle/pefchain

DISK_IMG=demo.c64

all: $(DISK_IMG)

$(DISK_IMG): script dirart.txt music.dir scenes/peron.dir
	${PEFCHAIN} ${PEFFLAGS} -o $@ -a dirart.txt -d 2 $<
	@echo

%.dir:
	make -C $(basename $@)

clean:
	@rm -f $(DISK_IMG)
	make -C $(basename $@) clean

.PHONY: *.dir clean
