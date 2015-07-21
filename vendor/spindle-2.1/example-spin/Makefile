all:		disk.d64

demo.prg:	demo.s
		xa -o $@ $<

disk.d64:	script demo.prg
		../spindle/spin -vv -o $@ $<
