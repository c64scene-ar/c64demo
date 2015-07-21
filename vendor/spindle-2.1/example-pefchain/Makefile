PEFCHAIN=../spindle/pefchain
#PEFFLAGS=-ww

all:		demo.d64

.PHONY:		demo.d64 *.dir

%.dir:
		make -C $(basename $@)

demo.d64:	script dirart.txt spindlelogo.dir music.dir ecmplasma.dir lft.dir
		${PEFCHAIN} ${PEFFLAGS} -o $@ -a dirart.txt -d 2 $<
