//============================================================
// color washer routine
//============================================================

colwash:
    lda color+$00      // load the current first color from table
    sta color+$27      // store in in last position of table to reset the cycle
    ldx #$00           // init X with zero

cycle1:
    lda color+1,x      // Start cycle by fetching next color in the table...
    sta color,x        // ...and store it in the current active position.
    sta $da58,x        // put into Color Ram
    inx                // increment X-Register
    cpx #$28           // have we done 40 iterations yet?
    bne cycle1         // if no, continue

colwash2:
    lda color2+$27     // load current last color from second table
    sta color2+$00     // store in in first position of table to reset the cycle
    ldx #$28

cycle2:
    lda color2-1,x     // Start cycle by fetching previous color in the table...
    sta color2,x       // ...and store it in the current active position.
    sta $daa8,x        // put into Color Ram
    dex                // decrease iterator
    bne cycle2         // if x not zero yet, continue

    rts                // return from subroutine

// color data table
// first 9 rows (40 bytes) are used for the color washer
// on start the gradient is done by byte 40 is mirroed in byte 1, byte 39 in byte 2 etc...

color:
    .byte $09,$09,$02,$02,$08
    .byte $08,$0a,$0a,$0f,$0f
    .byte $07,$07,$01,$01,$01
    .byte $01,$01,$01,$01,$01
    .byte $01,$01,$01,$01,$01
    .byte $01,$01,$01,$07,$07
    .byte $0f,$0f,$0a,$0a,$08
    .byte $08,$02,$02,$09,$09

color2:
    .byte $09,$09,$02,$02,$08
    .byte $08,$0a,$0a,$0f,$0f
    .byte $07,$07,$01,$01,$01
    .byte $01,$01,$01,$01,$01
    .byte $01,$01,$01,$01,$01
    .byte $01,$01,$01,$07,$07
    .byte $0f,$0f,$0a,$0a,$08
    .byte $08,$02,$02,$09,$09


//============================================================
// scroll
//============================================================

scroll:
    lda $0658+$00      // load the current first color from table
    sta $0658+$28      // store in in last position of table to reset the cycle
    ldx #$00           // init X with zero

cycles:
    lda $0658+1,x      // Start cycle by fetching next color in the table...
    sta $0658,x        // put into Color Ram
    inx                // increment X-Register
    cpx #$28           // have we done 40 iterations yet?
    bne cycles         // if no, continue

    rts                // return from subroutine
