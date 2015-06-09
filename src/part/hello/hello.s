#include "header.i"

* = $3000
loadaddr

cc .byt 0

setup
    lda  #$30
    sta  $d012
    rts

interrupt
    // nominal sync code with no sprites:
    sta  int_savea+1  // 10..16
    lda  $dc06        // in the range 1..7
    eor  #7
    sta  *+4
    bpl  *+2
    lda  #$a9
    lda  #$a9
    lda  $eaa5

    // at cycle 35

    stx  int_savex+1
    sty  int_savey+1

    // effect goes here
    lda  cc
    inc  cc
    sta  $d020    // set border color

int_savea  lda  #0
int_savex  ldx  #0
int_savey  ldy  #0
    lsr  $d019
    rti
