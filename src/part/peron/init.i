//============================================================
// Init the bitmap loaded at $2000
// Use the screen ram at 0xc00 (0x400 is being used by text screen ram)
//============================================================

init_bitmap
    ldx #$00
loaddccimage
    lda $3f40,x // Charmem data (Scren ram)
    sta $0c00,x
    lda $4040,x
    sta $0d00,x
    lda $4140,x
    sta $0e00,x
    lda $4240,x
    sta $0f00,x

    lda $4328,x // Colormem data
    sta $d800,x
    lda $4428,x
    sta $d900,x
    lda $4528,x
    sta $da00,x
    lda $4628,x
    sta $db00,x
    inx
bne loaddccimage

    rts


//============================================================
// clear screen
// a loop instead of kernal routine to save cycles
//============================================================

init_screen
    ldx #$00     // set X to zero (black color code)
    stx $d021    // set background color
    stx $d020    // set border color

clear
    lda #$20     // #$20 is the spacebar Screen Code
    sta $0400,x  // fill four areas with 256 spacebar characters
    sta $0500,x
    sta $0600,x
    sta $06e8,x
    lda #$00     // set foreground to black in Color Ram
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $dae8,x
    inx           // increment X
    bne clear     // did X turn to zero yet?
               // if not, continue with the loop
    rts           // return from this subroutine


//============================================================
// write the two line of text to screen center
//============================================================

// the two lines of text for color washer effect

line1: .text "         <<<<<<<<<<<<<<<<<<             "
line2: .text "     viva peron para tosh con <3        "

init_text
    ldx #$27          // iterate $28 times (40 cols)
loop_text
    lda line1,x      // read characters from line1 table of text...
    ///sta $0590,x      // ...and store in screen ram near the center
    sta $0658,x      // ...and store in screen ram near the center
    lda line2,x      // read characters from line1 table of text...
    sta $06a8,x
    //sta $05e0,x      // ...and put 2 rows below line1

    dex
    bne loop_text    // loop if we are not done yet
    rts
