PEFCHAIN=../vendor/spindle-1.0/spindle/pefchain

all:            demo.d64

.PHONY:         demo.d64 *.dir

%.dir:
	                make -C $(basename $@)

demo.d64:       script dirart.txt music.dir scenes/peron.dir 
	                ${PEFCHAIN} ${PEFFLAGS} -o $@ -a dirart.txt -d 2 $<

