//============================================================
// Example Project for C64 Tutorials  
// src by actraiser/Dustlayer
// Music: Ikari Intro by Laxity
//
// Simple Colorwash effect with a SID playing
//
// Tutorial: http://dustlayer.com/c64-coding-tutorials/2013/2/17/a-simple-c64-intro
// Dustlayer WHQ: http://dustlayer.com
//============================================================

//============================================================
// index file which loads all source code and resource files
//============================================================

//============================================================
//    specify output file
//============================================================

//.filenamespace lala
:BasicUpstart2(main)

//============================================================
// load resource files (for this small intro its just the sid)
//============================================================

.import source "res/load_resources.asm"

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

//============================================================
//    subroutines called during custom IRQ
//============================================================

.import source "fx/colorwash_sub.asm"
.import source "fx/scroller_sub.asm"

//============================================================
//  Main routine with IRQ setup and custom IRQ routine
//============================================================

.import source "main.asm"

