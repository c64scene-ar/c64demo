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
        .byt    0       ; end of tags hola

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

.(
+getslot_ptr
        lda isupkey
        lda isleftkey
        lda isrightkey
        lda isupkey
        lda isdownkey
        lda debughere
        lda copy_column
        lda viewport_x
        lda viewport_y
        lda hscroll_copy
        lda move_cam_right
        lda vcnt
        lda hcnt
        clc
        lda idiv40, x
        adc idiv25timeswdiv40,y
        asl ; each element on screen_tbl is a 16-bit number
            ; "a" now contains the offset in screen_tbl, which contains a pointer
            ; to the data of the screen pointed by the viewport.
        tax
        rts
.)
 
setup
        ; initial screen shift
        lda #$13 ; was 1b
        ora vcnt
        sta $d011

        lda $d016
        and #%11110000
        ora vcnt
        sta $d016

        lda #$1e ; IRQ setup
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
        ora     #%11100000 ; $D018 = %1110xxxx -> screenmem is at $3800 
                           ; Swap = $3c00 (%1111xxxx)
        sta     $d018
 
        ; Setup screen colors
        ;lda     #0
        ;sta     $D020 ; Border color (TODO should be taken from petscii file)
        ;lda     #0    
        ;sta     $D021 ; Background color (TODO should be taken from petscii file)

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

.(
        ldx #0
+memcpy_s
&l1     lda $5800, x
        sta $3800, x
&l2     lda $5900, x
        sta $3900, x
&l3     lda $5a00, x
        sta $3a00, x
&l4     lda $5b00, x
        sta $3b00, x
        dex
        bne memcpy_s
.)

.(
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
;        jsr swap_banks
        rts
.)

.(

;=====================================================================================================================
;
; memcpy_from_h( dst, src, x )
;
; copies all bytes starting from addr $4242
; until a position such as pos % 40 == 0, this is, the
; end of the screen that $4242 belongs to.
+memcpy_from_h
        sec
        lda #39
&mfh_i  ldx #$41
        sbc imod40, x
        tax
mfh_loop
&mfh_s  lda $4242, x
&mfh_d  sta $4343, x
        dex
        bpl mfh_loop
        rts
.)

.(        
;
; memcpy_to_h( src, dst, x )
;
; traditional memcpy, src, dst, n.
+memcpy_to_h
        clc
&mth_n  ldx #$41 

mth_loop
        dex
&mth_s  lda $4242, x
&mth_d  sta $4343, x
        cpx #0
        bne mth_loop
        rts
.)

; copy_column( dest, source, num_lines )
.(
+copy_column

&cc_n   ldx #$88
cc_loop
        ; This time the copy is not indexed, the address
        ; changed by the self-modifying code below.
&cc_s   lda $4242 
&cc_d   sta $4343 

        clc
        lda cc_s+1
        adc #40
        sta cc_s+1
        lda cc_s+2
        adc #0
        sta cc_s+2

        clc
        lda cc_d+1
        adc #40
        sta cc_d+1
        lda cc_d+2
        adc #0
        sta cc_d+2

        dex
        bne cc_loop
        rts
.)


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
screen_copy_back
        ldx #$ff
        ldy #4
screen_copy_b_loop
sc_b_s  lda $6666,x
sc_b_d  sta $7777,x
        dex
        cpx #$ff
        bne screen_copy_b_loop
        dey
        cpy #0
        beq screen_copy_b_done
        ldx #$ff
        dec sc_b_s+2
        dec sc_b_d+2
        jmp screen_copy_b_loop

screen_copy_b_done
        rts

;=====================================================================================================================
interrupt
        sei
        sta savea+1
        stx savex+1
        sty savey+1
 
        ;lda #0
        ;sta $d020

        ; Keyboard handling
        ;
        ; http://codebase64.org/doku.php?id=base:reading_the_keyboard
        ; http://sta.c64.org/cbm64kbdlay.html
        ;
        ; WASD movement.
        ;
        lda #$fd
        sta $dc00 ; up/down (W/S). it also gets the status of A.
        lda $dc01 ; read keyboard status
        cmp #$fd  ; fd, fd = W
        beq isupkey
        cmp #$df  ; fd, df = S
        beq isdownkey
        cmp #$fb  ; fd, fb = A
        bne checkrightkey ; just so I can place a far jmp in the next instruction
        jmp isleftkey
checkrightkey
        lda #$fb
        sta $dc00
        lda $dc01
        cmp #$fb  ; fb, fb = D
        bne nokey_trampoline
        jmp isrightkey
nokey_trampoline
        jmp nokey
isdownkey:
        clc
        lda viewport_y
        adc #25
        cmp imagesize+1
        bne down_limit_ok
        lda vcnt
        cmp #$0
        bne down_limit_ok
        jmp set_vscroll
down_limit_ok
        lda #$ff
        cmp vcnt
        beq down_apply_limit_cap
        dec vcnt
down_apply_limit_cap

        lda #$ff
        sta vs_copy_when_shifted_to+1

        lda #$0
        sta vs_nl2+1

        lda #$7
        sta vs_reset_to+1

        lda #24
        sta vs_nl1+1
        sta vs_nl2+1
        sta vsr_nl1+1
        sta vsr_nl2+1
        lda #$3
        sta vs_dl_h+1
        sta vsr_d_h+1
        lda #$c0
        sta vs_dl_l+1
        sta vsr_d_l+1

        lda #1
        sta going_down
        jmp vscroll


isupkey:
        lda viewport_y
        cmp #$0
        bne up_limit_ok
        lda vcnt
        cmp #$7
        bne up_limit_ok
        jmp nokey
up_limit_ok
        lda #$8
        cmp vcnt
        beq up_cnt_limit_cap
        inc vcnt 
up_cnt_limit_cap
        lda #$8
        sta vs_copy_when_shifted_to+1
        lda #$0
        sta vs_reset_to+1
        sta vs_nl1+1
        sta vs_nl2+1
        sta vs_dl_h+1
        sta vs_dl_l+1
        sta vsr_nl1+1
        sta vsr_nl2+1
        sta vsr_d_l+1
        sta vsr_d_h+1
        lda #0
        sta going_down
        jmp vscroll

isleftkey:
        lda viewport_x
        cmp #$0
        bne left_limit_ok
        lda hcnt
        cmp #$7
        bne left_limit_ok
        jmp nokey
left_limit_ok
        lda hcnt
        cmp #$8
        beq left_apply_limit_cap
        inc hcnt
left_apply_limit_cap
        lda #$8
        sta hs_copy_when_shifted_to+1

        lda #$0
        sta hs_reset_to+1
        ;sta hs_min1+1
        sta hs_nl1+1
        sta hs_nl2+1
        sta hs_dc+1
        sta hsr_nc2+1
        sta hsr_dc+1
        lda #0
        sta going_right
        jmp hscroll
isrightkey:
        clc
        lda viewport_x
        adc #40
        cmp imagesize+0
        bne right_limit_ok
        lda hcnt
        cmp #$0
        bne right_limit_ok
        jmp set_hscroll
right_limit_ok
        lda #$ff
        cmp hcnt
        beq right_apply_limit_cap
        dec hcnt
right_apply_limit_cap
        lda #$ff
        sta hs_copy_when_shifted_to+1

        lda #$0
        sta hs_nl2+1

        lda #$7
        ;sta hs_min1+1
        sta hs_reset_to+1

        lda #39
        sta hsr_nc2+1

        lda #39
        sta hs_nl1+1
        sta hs_dc+1
        sta hsr_dc+1

        lda #1
        sta going_right
 
        jmp hscroll



;=====================================================================================================================
vscroll
        ldx vcnt
vs_copy_when_shifted_to
        cpx #$8 
        beq vscroll_copy
        jmp set_vscroll

vscroll_copy
        lda #$0
        cmp going_down
        beq move_cam_up

move_cam_down:
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
        jmp vs_copy_from_left_screen

        ; shift the screen up, by copying from the current view to the current view address + 0x328
move_cam_up:
        dec viewport_y
        lda swap_addr
        clc
        adc #$0
        sta sc_b_s+1
        lda swap_addr+1
        adc #$3
        sta sc_b_s+2
        lda swap_addr
        clc
        adc #$28
        sta sc_b_d+1
        lda swap_addr+1
        adc #$3
        sta sc_b_d+2
        jsr screen_copy_back

        ; memcopy_from_h( swap, getslot_ptr(viewport_x, viewport_y + offset), viewport_x % 40 )
vs_copy_from_left_screen
        ; take the last line from the corresponding screen, which can
        ; be found by getting the current screen slot and then applying
        ; the offset needed.
        ldx viewport_x
        lda viewport_y
        clc
        
        ; vs_nl1/2 (new line) are either #0 or #24, depending on the direction

vs_nl1  adc #41 ; last line of the viewport (24 + 1 incremented before)
        tay
        jsr getslot_ptr ; returns in x, a
        
        lda viewport_y
        dec
        clc
vs_nl2  adc #41
        asl
        tay

        ; calculate source base address (left screen)
        clc
        lda imod25times40, y
        adc screen_tbl, x
        dec
        sta mfh_s+1
        lda imod25times40+1, y
        adc screen_tbl+1, x
        sta mfh_s+2

        ; calculate source offset (left screen)
        clc
        ldx viewport_x
        lda imod40, x
        adc mfh_s+1
        sta mfh_s+1
        lda #0
        adc mfh_s+2
        sta mfh_s+2

        ; copy to the corresponding line (first/last) of the framebuffer
        ; dl stands for dest line, which is actually an offet that refers
        ; to the beggining of the screen line.
        lda swap_addr
        clc    
vs_dl_l adc #$c0
        ;adc #0      ; TODO review this

        sta mfh_d+1
        lda swap_addr+1
vs_dl_h adc #3
        ;adc #0      ; TODO and this
        sta mfh_d+2

        ldx viewport_x
        lda imod40, x
        sta mfh_i+1   ; internal offset, copy_from viewport_x % 40 (until the end of the screen line)

        jsr memcpy_from_h


        ; memcopy_to_h( swap, getslot_ptr(viewport_x, viewport_y + offset), viewport_x % 40 )
vs_copy_from_right_screen
        ; take the last line from the corresponding screen, which can
        ; be found by getting the current screen slot and then applying
        ; the offset needed.
        ldx viewport_x
        
        lda imod40, x ; patch for coordinates aligned to 40, where theres no right screen.
        cmp #0
        beq vs_reset_to

        txa
        clc
        adc #40
        tax
        lda viewport_y
        clc
        
        ; vs_nl1/2 (new line) are either #0 or #24, depending on the direction

vsr_nl1 adc #0 ; last line (or first) of the viewport (if last, 24 + 1 incremented before)
        tay
        jsr getslot_ptr ; returns in x, a
        
        ; offset vertically
        lda viewport_y
        clc
vsr_nl2 adc #0
        asl ; this is because y is going to be used as an index of imod25times40, 
            ; which is a word list (not bytes), so as every element takes 2 bytes,
            ;I need to multiply this index.
        tay

        ; calculate source base address (right screen)
        clc
        lda imod25times40, y
        adc screen_tbl, x
        sta mth_s+1
        lda imod25times40+1, y
        adc screen_tbl+1, x
        sta mth_s+2

        ; here there's no offset, because the copy_to always starts from the
        ; beggining of the line, as it is the right screen. 

        ; copy to the corresponding line (first/last) of the framebuffer
        ; dl stands for dest line, which is actually an offet that refers
        ; to the beggining of the screen line.
        lda swap_addr
        clc    
vsr_d_l adc #$c0
        adc #0      ; TODO review this

        sta mth_d+1
        lda swap_addr+1
vsr_d_h adc #3
        adc #0      ; TODO and this
        sta mth_d+2

        ; adjust dest offset, for the right screen
        ldx viewport_x
        lda #41       ; TODO review
        sbc imod40, x
        clc
        adc mth_d+1
        sta mth_d+1
        lda mth_d+2
        adc #0
        sta mth_d+2

        ldx viewport_x
        lda imod40, x
        sta mth_n+1   ; internal offset, copy_to is always from 0.

        jsr memcpy_to_h
 
;=====================================================================================================================

vs_reset_to 
        ldx #0
        stx vcnt
set_vscroll
        lda vcnt
        and #%00000111
        sta vcapped+1
        lda $d011 ; vertical
        and #%11111000
vcapped ora #%11111111
        sta $d011  ; vertical

        jsr swap_banks
        jsr copy_to_swap
        jsr swap_banks
        jmp done_scrolling


;=====================================================================================================================
hscroll

        ldx hcnt
hs_copy_when_shifted_to
        cpx #$8
        beq hscroll_copy        
        jmp set_hscroll

hscroll_copy
        ; reset scroll counter
;hs_reset_to
;        ldx #$00  ; direction, 00 left, 07 right
;        stx hcnt

        lda #$0
      ;  cmp hs_min1+1
        cmp going_right
        beq move_cam_left

move_cam_right:
        inc viewport_x

        ; Screen copy, source is swap_addr + 1
        clc
        lda swap_addr
        adc #$1
        sta sc_s+1
        lda swap_addr+1
        sta sc_s+2
        lda swap_addr
        sta sc_d+1
        lda swap_addr+1
        sta sc_d+2
        jsr screen_copy
        jmp hs_copy_from_top_screen

        ; shift the screen left, by copying from the current view to the current view address + 1
move_cam_left:
        dec viewport_x

        lda swap_addr
        clc
        adc #$0
        sta sc_b_s+1
        lda swap_addr+1
        adc #$3
        sta sc_b_s+2
        lda swap_addr
        clc
        adc #$1
        sta sc_b_d+1
        lda swap_addr+1
        adc #$3
        sta sc_b_d+2
        jsr screen_copy_back

        ; TODO REMOVE ME
        ;jmp hs_copy_from_bottom_screen
        ;jmp hs_min2
        ; TODO REMOVE ME

        ; memcopy_from_h( swap, getslot_ptr(viewport_x, viewport_y + offset), viewport_x % 40 )
hs_copy_from_top_screen
debughere
        ; take the last line from the corresponding screen, which can
        ; be found by getting the current screen slot and then applying
        ; the offset needed.
        ldy viewport_y
        lda viewport_x

        clc
hs_nl1  adc #41 ; last column of the viewport (39 + 1 incremented before)
        tax
        jsr getslot_ptr ; returns in x, a
        
        lda viewport_y
        clc
hs_nl2  adc #0
        asl
        tay

        ; calculate source base address for the column (top screen)
        clc
        lda imod25times40, y
        adc screen_tbl, x
        sta cc_s+1
        lda imod25times40+1, y
        adc screen_tbl+1, x
        sta cc_s+2

        ; calculate source offset (top screen)
        ldx viewport_x
        lda going_right
        cmp #1
        bne top_copy_col
        dex
        ;dex

top_copy_col
        clc
        lda imod40, x
        adc cc_s+1
        sta cc_s+1
        lda #0
        adc cc_s+2
        sta cc_s+2

        ; copy to the corresponding line (first/last) of the framebuffer
        ; dl stands for dest line, which is actually an offet that refers
        ; to the beggining of the screen line.
        clc    
        lda swap_addr
hs_dc   adc #41
        sta cc_d+1

        lda swap_addr+1
        adc #0
        sta cc_d+2

        sec
        lda #25   
        ldy viewport_y
        sbc imod25, y
        sta cc_n+1 
        jsr copy_column

hs_copy_from_bottom_screen
        ldy viewport_y
        
        lda imod25, y
        cmp #0
        beq hs_reset_to

        tya
        clc
hsr_nc1 adc #24 ; a = viewport_y + 24, so we know to which screen maps (viewport_x, viewport_y+24), which belongs to the the bottom screen. 
        tay
        lda viewport_x
        clc
hsr_nc2 adc #0  ; 0 for left, 40 for right
        tax
        jsr getslot_ptr ; (viewport_x, viewport_y+24), returns in x, a
        
        ; calculate source base address (bottom screen)
        ldy viewport_x
;        lda hs_nl1+1
        lda going_right
        cmp #0
        beq bottom_no_dey
        dey  ; TODO WTF
bottom_no_dey
        clc
        lda imod40, y
        adc screen_tbl, x
        sta cc_s+1
        lda #0
        adc screen_tbl+1,x
        sta cc_s+2

        ; calculate dest address, where the column starts (bottom screen)
        clc
        sec
        ldy viewport_y
        lda #25
        sbc imod25, y
        asl
        tay

        lda imod25times40, y
        sta hsr_d_l+1
        lda imod25times40+1, y
        sta hsr_d_h+1

        clc
hsr_dc  lda #0
        adc hsr_d_l+1
        sta hsr_d_l+1
        lda #0
        adc hsr_d_h+1
        sta hsr_d_h+1
        

        lda swap_addr
        clc    
hsr_d_l adc #0
        sta cc_d+1
        lda swap_addr+1
hsr_d_h adc #0
        sta cc_d+2

        ldy viewport_y
        lda imod25, y
        sta cc_n+1   ; internal offset, copy_to is always from 0.

        jsr copy_column

;=====================================================================================================================
hs_reset_to 
        ldx #0
        stx hcnt
set_hscroll
;        lda $d016  ; horizontal
;        and #%11111000
;        ora hcnt
;        sta $d016  ; horizontal
        lda hcnt
        and #%00000111
        sta hcapped+1
        lda $d016 ; horizontal
        and #%11111000
hcapped ora #%11111111
        ;ora hcnt
        sta $d016  ; horizontal
        ;ldx hcnt

        jsr swap_banks
        jsr copy_to_swap
        jsr swap_banks

;=====================================================================================================================


done_scrolling
nocopy
nokey

savea   lda #0
savex   ldx #0
savey   ldy #0
    
;        lda #$00
;        sta $d020
;        sta $d021

        lsr $d019 ; ack interrupt
        cli


        rti


#include "parser/split/info.s"
vcnt .byt 7
hcnt .byt 7
#include "swap.s"
going_right .byt 1
going_down .byt 1
theend
