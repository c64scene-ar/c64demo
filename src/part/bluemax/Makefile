PART=bluemax

include ../common.mk

#SRC+=blue_max_charset.prg
#override OBJ+=blue_max_charset.prg

$(PART).pef: $(OBJ) blue_max_charset.prg
	    ${MKPEF} -o $@ $^

