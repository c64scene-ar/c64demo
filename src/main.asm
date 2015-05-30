//============================================================
//    some initialization and interrupt redirect setup
//============================================================
main:
    sei         // set interrupt disable flag

    jsr init_screen     // clear the screen
    jsr init_text       // write lines of text
    jsr init_bitmap
    
    jsr music.init     // init music routine now

    ldy #$7f    // $7f = %01111111
    sty $dc0d   // Turn off CIAs Timer interrupts ($7f = %01111111)
    sty $dd0d   // Turn off CIAs Timer interrupts ($7f = %01111111)
    lda $dc0d   // by reading $dc0d and $dd0d we cancel all CIA-IRQs in queue/unprocessed
    lda $dd0d   // by reading $dc0d and $dd0d we cancel all CIA-IRQs in queue/unprocessed

    lda #$01    // Set Interrupt Request Mask...
    sta $d01a   // ...we want IRQ by Rasterbeam (%00000001)

    lda $d011   // Bit#0 of $d011 indicates if we have passed line 255 on the screen
    and #$7f    // it is basically the 9th Bit for $d012
    sta $d011   // we need to make sure it is set to zero for our intro.

    lda #<main_loop   // point IRQ Vector to our custom irq routine
    ldx #>main_loop 
    sta $314    // store in $314/$315
    stx $315   

    lda #$00    // trigger first interrupt at row zero
    sta $d012

    cli                  // clear interrupt disable flag
    jmp *                // infinite loop

//============================================================
//    custom interrupt routine
//============================================================

main_loop:        
    dec $d019        // acknowledge IRQ / clear register for next interrupt

    jsr music.play	  // jump to play music routine

    lda #$3b     // Hi-Res
    sta $d011
    lda #$18     // Multicolor
    sta $d016
    lda #$38     // Screen ram = 0x400, bitmap at 2000
    sta $d018

    lda #<text_section   // point IRQ Vector to our custom irq routine
    ldx #>text_section
    sta $314    // store in $314/$315
    stx $315   

    //lda #$90    // trigger second interrupt at row zero
    ldx counter
    inx
    stx counter

    stx $d012

    jmp $ea81        // return to kernel interrupt routine

text_section:
    dec $d019        // acknowledge IRQ / clear register for next interrupt

    lda $D011
    and #%11011111
    sta $D011

    jsr colwash      // jump to color cycling routine
    jsr scroll      // jump to scroller


    lda #<main_loop   // point IRQ Vector to our custom irq routine
    ldx #>main_loop
    sta $314    // store in $314/$315
    stx $315   

    lda #$00    // trigger first interrupt at row zero
    sta $d012

    jmp $ea81        // return to kernel interrupt routine

counter: .byte 00