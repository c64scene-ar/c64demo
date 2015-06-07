# C64 Projects!

Compile the c64 demo project with xa65 + spindle! 
Check the Wiki for a route map and other projects.

# Documentation

We use spindle to chain our demo effects
http://www.linusakesson.net/software/spindle/

Every demo effect or "scene" must be autocontained
in the scenes/ directory and added to src/script

	# add your scenes in the order you want ame0

	scenes/peron/scene_peron.pef    -
	music/music.pef                 -
	#ecmplasma/ecmplasma.pef        ed = 0b
	#lft/lft.pef                    space
	-                               -

Every scene must have his own Makefile, and create a .pef,
 .efo, and .prg files.
Here is a sample of a Makefile that works with xa65

CFLAGS=-Wall
MKPEF= ../../../vendor/spindle-1.0/spindle/mkpef
PEF2PRG=../../../vendor/spindle-1.0/spindle/pef2prg

	all:                    hello.pef hello.prg

	hello.efo:              hello.asm
				xa -o $@ $<

	hello.pef:              hello.efo # Add more files here...
				${MKPEF} -o $@ $^

	%.prg:                  %.pef
				${PEF2PRG} -o $@ $^

Every scene .asm must have a EFO header for the loader to work
nicely, and its defined like this:

		// efo header

		.byte   "EFO2"          // fileformat magic
		.word   0               // prepare routine
		.word   setup           // setup routine
		.word   interrupt       // irq handler
		.word   main            // main routine
		.word   0               // fadeout routine
		.word   0               // cleanup routine
		.word   0               // location of playroutine call

		// tags go here

		//.byt  "P",$04,$07     // range of pages in use
		//.byt  "I",$10,$1f     // range of pages inherited
		//.byt  "Z",$02,$03     // range of zero-page addresses in use
		//.byt  "S"             // i/o safe
		//.byt  "X"             // avoid loading
		//.byt  "M",<play,>play // install music playroutine

		.byt    0

		.word   loadaddr
		* = $3000
		loadaddr

		setup
		interrupt
		main


# Memory Map

Here we'll define the memory map and important 
memory locations for this demo

Remember:
The Spindle runtime occupies 1 kB of C64 RAM at $c00-$fff, as well as zero-page locations $f0-$f7.

Spindle recommends: code from $3000 to $ffff.
Start demo code at $3000, and place speedcode an tables 
from $8000 and up.

Here is a memory map of the spindle runtime:

	$c00-$d7f       Resident part of loader, handles serial transfer.
	$d80-$dff       Handover area.
	$e00-$ebf       Decruncher.
	$ec0-$eeb       Blank effect.
	$eec-$eff       File specification to bootstrap the first demo part.
	$f00-$fff       Sector buffer.



