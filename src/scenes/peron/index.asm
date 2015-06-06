//============================================================
// .efo header
//============================================================

.pc = $0 ".efo header"

.var prepare = 0
.var setup = 0
.var interrupt = 0
.var fadeout = 0
.var cleanup = 0
.var callmusic = 0

.text "EFO2"          // fileformat magic
.word prepare         // prepare routine
.word setup           // setup routine
.word interrupt       // irq handler
.word main            // main routine
.word fadeout         // fadeout routine
.word cleanup         // cleanup routine
.word callmusic       // location of playroutine call

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

//============================================================
// load resource files
//============================================================

//.import source "res/load_resources.asm"

//============================================================
// tables and strings of data 
//============================================================

.import source "init/statictext_data.asm"
.import source "fx/colorwash_data.asm"
.import source "fx/scroller_data.asm"

//============================================================
// one-time initialization routines
//============================================================

.import source "init/clearscreen_init.asm"
.import source "init/statictext_init.asm"
.import source "init/bitmap_init.asm"

//============================================================
//    subroutines called during custom IRQ
//============================================================

.import source "fx/colorwash_sub.asm"
.import source "fx/scroller_sub.asm"

//============================================================
//  Main routine with IRQ setup and custom IRQ routine
//============================================================

.import source "main.asm"
