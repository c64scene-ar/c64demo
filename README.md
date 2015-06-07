# C64 Projects!

Compile the c64 demo project with KickAssembler

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
Here is a sample of a Makefile that works with KickAssembler
instead of default xa65 of spindle

	KICKASS_PATH=../../../vendor/KickAss.jar
	SPINDLE_DIR=../../../vendor/spindle-1.0/spindle
	MKPEF=$(SPINDLE_DIR)/mkpef
	PEF2PRG=$(SPINDLE_DIR)/pef2prg

	SCENE=scene_peron

	SOURCES=$(wildcard *.asm)

	all: $(SCENE).pef $(SCENE).prg

	$(SCENE).efo: index.asm $(SOURCES)
		java -jar $(KICKASS_PATH) $< -o $@ -binfile -showmem -symbolfile

	$(SCENE).pef: $(SCENE).efo
		${MKPEF} -o $@ $^

	%.prg: %.pef
		${PEF2PRG} -o $@ $<

	clean:
		@rm -f $(SCENE).* index.sym

	.PHONY: clean


Every scene .asm must have a EFO header for the loader to work
nicely, and its defined like this:

	//============================================================
	// .efo header
	//============================================================

	.pc = $0 ".efo header"

	.text "EFO2"          // fileformat magic
	.word prepare         // prepare routine
	.word setup           // setup routine
	.word interrupt       // irq handler
	.word 0               // main routine
	.word 0               // fadeout routine
	.word 0               // cleanup routine
	.word 0               // location of playroutine call

	// tags
	//.byt "P", $04, $07    // range of pages in use
	//.byt "I",$10,$1f      // range of pages inherited
	//.byt "Z",$02,$03      // range of zero-page addresses in use
	//.byt "S"              // i/o safe
	//.byt "X"              // avoid loading
	//.byt "M",<play,>play  // install music playroutine
	.byte 0                 // end-of-tags

	.word load_addr

	.pc = $c000 "Main"
	load_addr:
	
	// Here we start to code our nice fx


# Memory Map

Here we'll define the memory map and important 
memory locations for this demo




