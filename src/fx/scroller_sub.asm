scroll:
    lda $0590+$00      // load the current first color from table
    sta $0590+$28      // store in in last position of table to reset the cycle
    ldx #$00           // init X with zero

cycles:
    lda $0590+1,x      // Start cycle by fetching next color in the table...
    sta $0590,x        // put into Color Ram
    inx                // increment X-Register
    cpx #$28           // have we done 40 iterations yet?
    bne cycles         // if no, continue

    rts                // return from subroutine