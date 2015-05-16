//============================================================
// Example Project for C64 Tutorials  
// Code by actraiser/Dustlayer
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

.import source "code/load_resources.asm"

//============================================================
// tables and strings of data 
//============================================================

.import source "code/data_static_text.asm"
.import source "code/data_colorwash.asm"

//============================================================
// one-time initialization routines
//============================================================

.import source "code/init_clear_screen.asm"
.import source "code/init_static_text.asm"

//============================================================
//    subroutines called during custom IRQ
//============================================================

.import source "code/sub_colorwash.asm"

//============================================================
//  Main routine with IRQ setup and custom IRQ routine
//============================================================

.import source "code/main.asm"

