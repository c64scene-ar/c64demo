#include "header.i"

//============================================================
// initialization
//============================================================

#include "init.i"
#include "fx.i"

prepare
    jsr  init_screen     // clear the screen
    jsr  init_text       // write lines of text
    jsr  init_bitmap
    rts

//============================================================
// setup
//============================================================

setup:
    lda  $d011   // Bit#0 of $d011 indicates if we have passed line 255 on the screen
    and  #$7f    // it is basically the 9th Bit for $d012
    sta  $d011   // we need to make sure it is set to zero for our intro.

    lda  #$00    // trigger first interrupt at row zero
    sta  $d012

    rts


//============================================================
// interrupt routine
//============================================================

interrupt:
    lda #$3b     // Hi-Res
    sta $d011
    lda #$18     // Multicolor sta $d016
    lda #$38     // Screen ram = 0xC00, bitmap at 2000
    sta $d018

    lda #<text_section   // point IRQ Vector to our custom irq routine
    ldx #>text_section
    sta $314    // store in $314/$315
    stx $315

    lda #$90    // trigger second interrupt at row zero
    sta $d012

    jmp $ea81

text_section:
    dec $d019        // acknowledge IRQ / clear register for next interrupt

    lda #$1b
    sta $D011
    lda #$15 //8     // Screen ram = 0x400, bitmap at 2000
    sta $d018

    jsr colwash      // jump to color cycling routine
    jsr scroll      // jump to scroller

    lda #<interrupt   // point IRQ Vector to our custom irq routine
    ldx #>interrupt
    sta $314    // store in $314/$315
    stx $315

    lda #$00    // trigger first interrupt at row zero
    sta $d012

    jmp $ea81


* = $2000
.bin 0, 0, "dcc.bin"
