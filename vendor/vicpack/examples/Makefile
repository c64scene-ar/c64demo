.PHONY:	all
all:   	mc.png.prg hires.png.prg hires_w_sprites.png.prg fli.png.prg mci.png.prg 
#asslace.png.prg

fli.png.prg: fli.png
	../vicpack -p -fli -pepto fli.png

hires_w_sprites.png.prg: hires_w_sprites.png
	../vicpack -p -overlay -pepto hires_w_sprites.png

mc.png.prg: mc.png
	../vicpack -p -mc -pepto mc.png

hires.png.prg: hires.png
	../vicpack -p -pepto hires.png

mci.png.prg: mci.png
	../vicpack -p -mci -pepto mci.png

#asslace.png.prg: asslace.png
#	vicpack -p -ass -pepto asslace.png

# --------------------------------------------------------------------------
# Cleanup rules

.PHONY:	clean
clean:
	rm -f *~ *.bin *.a *.prg
	
