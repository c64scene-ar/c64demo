        ; efo header

        .byt    "EFO2"  ; fileformat magic
        .word   0       ; prepare routine
        .word   setup   ; setup routine
        .word   interrupt       ; irq handler
        .word   0    ; main routine
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
        * = $2000
loadaddr

setup
       
        ;lda     #0
        ;sta     $d015 ; Disable sprites
        ;sta     $d017 ; Disable sprite double height
        ;sta     $d01b ; Reset sprite priority
        ;sta     $d01c ; Disable sprite multicolor
        ;sta     $d01d ; Disable sprite double width

        ;lda     $D016 ;enable multicolor
        ;ora     #$10
        ;sta     $D016

        ; Setup CIA ports (for keyboard)
        lda #$0
        sta $dc03   ; port b ddr (input)
        lda #$ff
        sta $dc02   ; port a ddr (output)

        ; Setup VIC bank configuration 
        ;
        ; http://www.linusakesson.net/software/spindle/v2.php
        ;
        lda     #$3c       ; $0000-$3fff (Spindle)
        sta     $dd02

        ; Screen configuration
        ;
        ; http://codebase64.org/doku.php?id=base:vicii_memory_organizing
        ;
        lda     #%00001111 ; Char ROM + Unused bit, leave them alone 
        and     $d018
        ora     #%11100000 ; $D018 = %1110xxxx -> screenmem is at $3800 
                           ; Swap = $3c00 (%1111xxxx)
        sta     $d018
 
        ; Setup screen colors
        lda     #0
        sta     $D020 ; Border color (TODO should be taken from petscii file)
        lda     #0    
        sta     $D021 ; Background color (TODO should be taken from petscii file)

        ; Setup initial color ram
        ;
        ; memcpy((void*)0xd800, (void*)0x2000, 0x400);
        ;
        clc
        ldx viewport_x
        lda idiv40, x
        ldx viewport_y
        adc idiv25timeswdiv40,x
        asl ; each element on screen_tbl is a 16-bit number
        tax
        ldy screen_tbl, x
        sty l1+1
        sty l2+1
        sty l3+1
        sty l4+1
        ldy screen_tbl+1, x
        sty l1+2
        iny
        sty l2+2
        iny
        sty l3+2
        iny
        sty l4+2 

        ldx #0
memcpy_s
l1      lda $5800, x
        sta $3800, x
l2      lda $5900, x
        sta $3900, x
l3      lda $5a00, x
        sta $3a00, x
l4      lda $5b00, x
        sta $3b00, x
        dex
        bne memcpy_s
 
        ldx #0
memcpy_c
c1      lda $7c00, x
        sta $d800, x
c2      lda $7d00, x
        sta $d900, x
c3      lda $7e00, x
        sta $da00, x
c       lda $7f00, x
        sta $db00, x
        dex
        bne memcpy_c

       rts

interrupt
        sta savea+1
        stx savex+1
        sty savey+1

        ; Keyboard polling
        ;
        ; http://codebase64.org/doku.php?id=base:reading_the_keyboard
        ; http://sta.c64.org/cbm64kbdlay.html
        ;
        lda #$fe
        sta $dc00 ; select keyboard column
        lda $dc01 ; read key statuses
        cmp #$fb  ; right/left cursor
        bne nokey ; any other key = no key
      
        inc cnt
scrollear
        lda $d016
        and #%11111000
        ora cnt
        sta $d016

        ldx cnt
        cpx #$8
        bne nokey

        ldx #$00
        stx cnt
        ; hay que copiar
scr_cpy
        ;lda $2000, x
        ;sta $2001, x
        ;lda $2100, x
        ;sta $2101, x
        ;lda $2200, x
        ;sta $2201, x
        ;lda $2300, x
        ;sta $2301, x

        ;lda $d800, x
        ;sta $d801, x
        ;lda $d900, x
        ;sta $d901, x
        ;lda $da00, x
        ;sta $da01, x
        ;lda $db00, x
        ;sta $db01, x

        dex
        bne scr_cpy

nokey

savea   lda #0
savex   ldx #0
savey   ldy #0
    
        lsr $d019 ; ack interrupt

        rti

cnt .byt 00
copiando .byt 00

#include "parser/split/info.s"
