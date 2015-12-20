        ; efo header

        .byt    "EFO2"      ; fileformat magic
        .word   0       ; prepare routine
        .word   setup       ; setup routine
        .word   0 ;interrupt    ; irq handler
        .word   0       ; main routine
        .word   0       ; fadeout routine
        .word   0       ; cleanup routine
        .word   0       ; location of playroutine call

        ; tags go here

        ;.byt   "P",$04,$07 ; range of pages in use
        ;.byt   "I",$10,$1f ; range of pages inherited
        ;.byt   "Z",$02,$03 ; range of zero-page addresses in use
        ;.byt   "X"     ; avoid loading
        ;.byt   "M",<play,>play ; install music playroutine

        .byt    "S"     ; i/o safe
        .byt    0       ; end of tags

        .word   loadaddr
        * = $c000
loadaddr

setup

        lda     #%00001111
        and     $d018
        ora     #%10000000
        sta     $d018
        
;        lda     #$3d
;        sta     $dd02
;        lda     #0
;        sta     $d015
;        sta     $d017
;        sta     $d01b
;        sta     $d01c
;        sta     $d01d

;        lda     #$30
;        sta     $d012

;        lda     $D016 ;enable multicolor
;        ora     #$10
;        sta     $D016


;        lda     #$3B ;enable bitmap mode
;        sta     $D011

;        lda     #$08 ; video matrix = 4000, bitmap base = 6000
;        sta     $D018

        lda     #0
        sta     $D020
        lda     #0
        sta     $D021

;
; memcpy((void*)0xd800, (void*)0x2000, 0x400);
;
        ldx #0
memcpy
        lda $8000, x
        sta $d800, x
        lda $8100, x
        sta $d900, x
        lda $8200, x
        sta $da00, x
        lda $8300, x
        sta $db00, x
        dex
        bne memcpy

        rts

interrupt
        sta savea+1
        stx savex+1
        sty savey+1

        lda #<irq_stable    ; +2, 2
        ldx #>irq_stable    ; +2, 4
        sta $fffe       ; +4, 8
        stx $ffff       ; +4, 12
        inc $d012       ; +6, 18
        asl $d019       ; +6, 24
        nop
        tsx         ; +2, 26
        cli         ; +2, 28
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop

irq_stable
        ; aca me da 65, o 128, o 130 (65*2 +- 2?).
        txs         ; +2, 9~10
        ;nop        ; Pal-n

        ; 42 cycles

        ldx #$08        ; +2, 11~12
        dex             ; +2 * 8, 27~28
        bne *-1         ; +3 * 7, +2, 50~51
        bit $00         ; +3, 53~54

        lda $d012       ; +4, 57~58
        cmp $d012       ; +4, 61~62
        beq *+2         ; +2/+3, 64

        lda #$05
        sta $d020
        sta $d021
  
;__CODE__

; never reached

        lda #<interrupt ; +2, 2
        ldx #>interrupt ; +2, 4
        sta $fffe       ; +4, 8
        stx $ffff       ; +4, 12


        inc cnt
        lda cnt
        and #%00000111
        ora $d016
        sta $d016


        ldx ln_last
        cpx ln_split1
        beq do_split2
        ldx ln_split1
        jmp set_split
 
do_split2:
        ldx ln_split2
set_split:
        stx $d012
        stx ln_last
     ;   sta $d012


        
savea   lda #0
savex   ldx #0
savey   ldy #0
    
        lsr $d019

        ; just to measure the code..
        lda #$00
        lda #$00
        sta $d020
        sta $d021


        rti

ln_last .byt 180
ln_split1 .byt 100
ln_split2 .byt 180
cnt .byt 00


sctext  .byt "Hello!"
