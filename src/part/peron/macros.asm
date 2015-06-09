// $DD00 = %xxxxxx11 -> bank0: $0000-$3fff
// $DD00 = %xxxxxx10 -> bank1: $4000-$7fff
// $DD00 = %xxxxxx01 -> bank2: $8000-$bfff
// $DD00 = %xxxxxx00 -> bank3: $c000-$ffff
.macro SetVICBank0() {
    lda $DD00
    //and #%11111100
    ora #%00000011
    sta $DD00
}

.macro SetVICBank1() {
    lda $DD00
    and #%11111100
    ora #%00000010
    sta $DD00
}

.macro SetVICBank2() {
    lda $DD00
    and #%11111100
    ora #%00000001
    sta $DD00
}

.macro SetVICBank3() {
    lda $DD00
    and #%11111100
    //ora #%00000000
    sta $DD00
}   


.macro SetBorderColor(color) {
    lda #color
    sta $d020
}

.macro SetBackgroundColor(color) {
    lda #color
    sta $d021
}

.macro SetMultiColor1(color) {
    lda #color
    sta $d022
}

.macro SetMultiColor2(color) {
    lda #color
    sta $d023
}

.macro SetMultiColorMode() {
    lda $d016
    ora #16
    sta $d016   
}

.macro SetScrollMode() {
    lda $D016
    eor #%00001000
    sta $D016
}

.macro ClearColorRam(clearByte) {
    lda #clearByte
    ldx #0
!loop:
    sta $D800, x
    sta $D800 + $100, x
    sta $D800 + $200, x
    sta $D800 + $300, x
    inx
    bne !loop-
}

.macro ClearScreen(screen, clearByte) {
    lda #clearByte
    ldx #0
!loop:
    sta screen, x
    sta screen + $100, x
    sta screen + $200, x
    sta screen + $300, x
    inx
    bne !loop-
}