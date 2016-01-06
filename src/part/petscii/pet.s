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


;
; getslot_ptr( x, y )
;
; Given a pair of coordinates (0..40,0.25), received in the
; x/y registers, returns an offset that can be used to
; access either screen_tbl or color_tbl, tables which contain
; pointers to where the petscii frames are allocated.
; returns both in a and x
;

getslot_ptr
        clc
        lda idiv40, x
        adc idiv25timeswdiv40,y
        asl ; each element on screen_tbl is a 16-bit number
            ; "a" now contains the offset in screen_tbl, which contains a pointer
            ; to the data of the screen pointed by the viewport.
        tax
        rts
 
setup

      ; initial irq + shift
      lda #$1b
      ora cnt
      sta $d011
      lda #$1e
      sta $d012

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
        ora     #%11100000 ; $D018 = %1110xxxx -> screenmem is at $pl3800 
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
        ldy viewport_y
        jsr getslot_ptr
        ; TODO - generalize and copy color matrix as well
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

        ; copy initial screen to swap
        jsr copy_to_swap
        jsr swap_banks
        rts

;
; memcpy_from_h( dst, src, x )
;
; copies all bytes starting from addr $4242
; until a position such as pos % 40 == 0, this is, the
; end of the screen that $4242 belongs to.
memcpy_from_h
        sec
        lda #39
mfh_p2  ldx #$41
        sbc imod40, x
        tax
mfh_loop
mfh_p1  lda $4242, x
mfh_p0  sta $4343, x
        dex
        bpl mfh_loop
        rts
        
;
; memcpy_to_h( src, dst, x )
;
; traditional memcpy, src, dst, n.
memcpy_to_h
        clc
mth_p2  ldx #$41

mth_loop
mth_p1  lda $4242, x
mth_p0  sta $4343, x
        dex
        bpl mth_loop
        rts


;------------------------
swap_banks
        ldy swap_addr+2 
        ldx swap_addr+0 
        stx swap_addr+2 
        sty swap_addr+0 
        ldy swap_addr+3
        ldx swap_addr+1
        stx swap_addr+3
        sty swap_addr+1
        cpy #$3c        ; WARNING hardcoded, depends on using $3cxx for one bank
        bne swap_to_two
swap_to_one
        ;
        ; Screen configuration
        ;
        ; http://codebase64.org/doku.php?id=base:vicii_memory_organizing
        ;
        ; Active frame buffer at $3800, display at $3c00
        ;
        lda     #%00001111 ; Char ROM + Unused bit, leave them alone 
        and     $d018
        ora     #%11100000 ; $D018 = %1110xxxx -> screenmem is at $3800 
        sta     $d018
        jmp swap_finish
swap_to_two
        ;
        ; Active frame buffer at $3c00, display at $3800
        ;
        lda     #%00001111 ; Char ROM + Unused bit, leave them alone 
        and     $d018

        ora     #%11110000 ; $D018 = %1111xxxx -> screenmem is at $3c00 
        sta     $d018
swap_finish
        rts

; copy current screen to swap
copy_to_swap
        ; the second element is the currently selected bank
        ldx swap_addr+2
        stx sc_s+1
        ldx swap_addr+3
        stx sc_s+2

        ; the first one is the frame buffer
        ldx swap_addr+0
        stx sc_d+1
        ldx swap_addr+1
        stx sc_d+2
        jsr screen_copy
        rts

;------------------------
screen_copy
        ldx #0
        ldy #4
screen_copy_loop
sc_s    lda $3828,x
sc_d    sta $3800,x
        inx
        cpx #0
        bne screen_copy_loop
        dey
        cpy #0
        beq screen_copy_done
        ldx #0
        inc sc_s+2
        inc sc_d+2
        jmp screen_copy_loop

screen_copy_done
        lda #$38
        sta sc_s+2
        sta sc_d+2


        rts
;------------------------

interrupt
        sei
        sta savea+1
        stx savex+1
        sty savey+1
 
        lda #$00
        sta $d020
        sta $d021

        ; Keyboard polling
        ;
        ; http://codebase64.org/doku.php?id=base:reading_the_keyboard
        ; http://sta.c64.org/cbm64kbdlay.html
        ;
        lda #$fe
        sta $dc00 ; select keyboard column
        lda $dc01 ; read key statuses
;       cmp #$fb  ; right/left cursor
        cmp #$7f  ; right/left cursor
        beq somekey ; any other key = no key
        jmp nokey
somekey:
        ;inc cnt ; opposite direction
        dec cnt

vscroll_down
        ;lda $d016 ; horizontal
        lda $d011  ; vertical
        and #%11111000
        ora cnt
        ;sta $d016  ; horizontal
        sta $d011  ; vertical
        ldx cnt
        ;cpx #$8   ; opposite direction
        cpx #$0
        beq vscroll_down_copy
        jmp nocopy

vscroll_down_copy
        ; reset scroll counter
        ;ldx #$00  ; opposite direction
        ldx #7
        stx cnt

        ; memcopy_from_h( swap, getslot_ptr(viewport_x, viewport_y + 25 + 1), viewport_x % 40 )

        ; shift the screen up, by copying from the current view + 40 (0x28) to the current view address
        inc viewport_y
        lda swap_addr
        clc
        adc #$28
        sta sc_s+1
        lda swap_addr+1
        sta sc_s+2
        lda swap_addr
        sta sc_d+1
        lda swap_addr+1
        sta sc_d+2
        jsr screen_copy

        ; take the last line from the corresponding screen, which can
        ; be found by getting the current screen slot and then applying
        ; the offset needed.
        ldx viewport_x
        lda viewport_y
        clc
        adc #24 ; last line of the viewport (24 + 1 incremented before)
        tay
        jsr getslot_ptr ; returns in x, a
        
        ; TODO adc viewport_x % 40 to the memcpy_from "x" parameter
        lda viewport_y
        clc
        adc #24
        asl
        tay
        clc
        lda imod25times40, y
        adc screen_tbl, x
        sta mfh_p1+1
        lda imod25times40+1, y
        adc screen_tbl+1, x
        sta mfh_p1+2

        ; copy to line #25 (offset 0x3c0) of the framebuffer
        lda swap_addr
        clc    
        adc #$c0
        sta mfh_p0+1
        lda swap_addr+1
        clc ; TODO we probably dont want this
        adc #3
        sta mfh_p0+2

        ldx viewport_x
        lda imod40, x
        sta mfh_p2+1   ; internal offset, copy_from viewport_x % 40 (until the end of the screen line)

        jsr memcpy_from_h

 wait_for_vblank
        lda $d012
        cmp #$1e
        bne wait_for_vblank
        lda $d011
        and #%10000000
        cmp #%00000000
        bne wait_for_vblank

        ldx #7
        stx cnt

        lda $d011  ; vertical
        and #%11111000
        ora cnt
        ;sta $d016  ; horizontal
        sta $d011  ; vertical

        jsr swap_banks

        jsr copy_to_swap

        ; // memcopy_from_h
        
        ; TODO memcopy_to_h()
        ; need to shift the entire screen up, and copy the next row
        ; from a position defined by the viewport + the screen table

nocopy
nokey

savea   lda #0
savex   ldx #0
savey   ldy #0
    
        lda #$00
        sta $d020
        sta $d021

        lsr $d019 ; ack interrupt
        cli


        rti

cnt .byt 7
copiando .byt 00

; TODO send to zero page vectors (https://www.c64-wiki.com/index.php/Indirect-indexed_addressing), maybe.. idk
;swap_addr .word $3800, $3c00
swap_addr .word $3c00, $3800

#include "parser/split/info.s"
