INIT = $1000
PLAY = $1003

        ; efo header
        .byt    "EFO2"  ; fileformat magic
        .word   0       ; prepare routine
        .word   setup   ; setup routine
        .word   interrupt       ; irq handler
        .word   0    ; main routine
        .word   0       ; fadeout routine
        .word   0       ; cleanup routine
        .word   0       ; location of playroutine call;;;
        .byt    0       ; end of tags 

        .word   loadaddr
        * = $e000
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
        lda debughere   
        lda hscroll_do_left_scroll
        lda screen_copy
        lda screen_copy_back

        lda hs_copy_from_top_screen
        lda hscroll_do_left_scroll
        lda viewport_x
        lda viewport_y
        lda hcnt
;        lda hswap_prepare_swap
        lda copy_column

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
        lda #$13 ; was 13
        ora vcnt
        sta $d011


        lda $d016
        and #%11110000
        ora vcnt
        sta $d016

        lda #$01 ; IRQ setup
        sta $d012

        lda #0
        jsr INIT
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
        jsr copy_to_swap_stage_1
        jsr copy_to_swap_stage_2
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
screen_copy_loop
sc_s    lda $3828,x
sc_d    sta $3800,x
        inx
        cpx #$fa
        bne screen_copy_loop
        rts

;------------------------
screen_copy_back
        ldx #$f9
screen_copy_b_loop
sc_b_s  lda $6666,x
sc_b_d  sta $7777,x
        dex
        cpx #$ff
        bne screen_copy_b_loop
        rts

;=====================================================================================================================


interrupt
        sei
        sta savea+1
        stx savex+1
        sty savey+1
 
        jsr PLAY
        
;        jmp skip_vshift

        lda #1
        sta $d020

        ; Keyboard handling
        ;
        ; http://codebase64.org/doku.php?id=base:reading_the_keyboard
        ; http://sta.c64.org/cbm64kbdlay.html
        ;
        ; WASD movement.
        ;

        lda hcnt
        cmp #$7
        beq check_vcont
        jmp hkeep_moving

check_vcont
        lda vcnt
        cmp #$7
        beq read_keyboard
        jmp vkeep_moving

read_keyboard
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
        adc #24
        cmp imagesize+1
        bne down_limit_ok
        lda vcnt
        cmp #$7
        bne down_limit_ok
        jmp nokey
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
        lda #$7
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
        lda #$7
        sta hs_copy_when_shifted_to+1

        lda #$0
        sta hs_reset_to+1

        sta hs_nl1+1
        sta hs_nl2+1
        sta hs_dc+1
        sta hsr_nc2+1
        sta hsr_dc+1

        lda #0
        sta going_right

;        jsr swap_bank_registers
        ;jsr swap_banks

        jmp hscroll
isrightkey:
        clc
        lda viewport_x
        adc #38
        cmp imagesize+0
        bne right_limit_ok
        lda hcnt
        cmp #$7
        bne right_limit_ok
        jmp nokey
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

hkeep_moving
        lda #$1
        cmp going_right
        beq hmright
        inc hcnt
        jmp hscroll
hmright
        dec hcnt
        jmp hscroll

vkeep_moving
        lda #$1
        cmp going_down
        beq vmdown
        inc vcnt
        jmp vscroll
vmdown
        dec vcnt
        jmp vscroll

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
        jmp vs_copy_from_left_screen

        ; shift the screen up, by copying from the current view to the current view address + 0x328
move_cam_up:
        dec viewport_y

        ; memcopy_from_h( swap, getslot_ptr(viewport_x, viewport_y + offset), viewport_x % 40 )
vs_copy_from_left_screen
        ; take the last line from the corresponding screen, which can
        ; be found by getting the current screen slot and then applying
        ; the offset needed.
        ldx viewport_x
        ldy viewport_y

        lda #1
        cmp going_down
        beq skip_getslot_dey
        dey
skip_getslot_dey
        tya

        clc        
        ; vs_nl1/2 (new line) are either #0 or #24, depending on the direction
vs_nl1  adc #41 ; last line of the viewport (24 + 1 incremented before)
        tay
        jsr getslot_ptr ; returns in x, a

        ldy viewport_y        
        lda #1
        cmp going_down
        beq skip_src_dey
        dey
skip_src_dey
        tya

        clc
vs_nl2  adc #41
        asl
        tay

        ; calculate source base address (left screen)
        clc
        lda imod25times40, y
tblref1
        adc screen_tbl, x
        dec
        sta mfh_s+1
        lda imod25times40+1, y
tblref2
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

        ldy viewport_y        
        lda #1
        cmp going_down
        beq skip_src_up_getslot_dey
        dey
skip_src_up_getslot_dey
        tya

        clc
        ; vs_nl1/2 (new line) are either #0 or #24, depending on the direction

vsr_nl1 adc #0 ; last line (or first) of the viewport (if last, 24 + 1 incremented before)
        tay
        jsr getslot_ptr ; returns in x, a
        
        ; offset vertically
        ldy viewport_y        
        lda #1
        cmp going_down
        beq skip_src_up_dey
        dey
skip_src_up_dey
        tya

        clc
vsr_nl2 adc #0
        asl ; this is because y is going to be used as an index of imod25times40, 
            ; which is a word list (not bytes), so as every element takes 2 bytes,
            ;I need to multiply this index.
        tay

        ; calculate source base address (right screen)
        clc
        lda imod25times40, y
tblref3
        adc screen_tbl, x
        sta mth_s+1
        lda imod25times40+1, y
tblref4
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
        lda #0
        cmp going_down
        beq set_vscroll
        stx vcnt
set_vscroll
        lda vcnt
        cmp #$08
        beq vscroll_skip_reg

        and #%00000111
        sta vcapped+1
        lda $d011 ; vertical
        and #%11111000
vcapped ora #%11111111
        sta $d011  ; vertical

vscroll_skip_reg
        lda #$1
        sta $d020

        cmp going_down
        bne vscroll_do_up_scroll
        jmp vscroll_do_down_scroll

.(
+vscroll_do_up_scroll
        lda vcnt

        cmp #$8
        beq vswap_swap

        cmp #$1
        beq vswap_prepare_swap

        cmp #$2
        beq vswap_prepare_swap

        cmp #$7
        beq copy_color_ram

        ; cases 3,4,5,6
        lda vcnt
        sta $d020

        sec
        lda #$6
        sbc vcnt
        tax
        lda fasteps_lo, x
        sta sc_wb_sl+1
        clc
        adc #40
        sta sc_wb_dl+1
        lda fasteps_hi, x
        sta sc_wb_sh+1
        adc #0
        sta sc_wb_dh+1
        jsr sc_b_wrapper
        jmp done_scrolling


vswap_prepare_swap
        ;lda #08
        ;sta $d020

        cmp #$1
        bne vswap_two
        jsr copy_to_swap_stage_1
        jmp done_scrolling
vswap_two
        jsr copy_to_swap_stage_2
        jmp done_scrolling

vswap_swap
        lda #08
        sta $d020

vswap_one_dec
        jsr swap_banks
        lda #$0
        sta vcnt
        lda $d011 ; vertical
        and #%11111000
        sta $d011  ; vertical
        jmp done_scrolling

copy_color_ram
        ; not implemented
        lda #0
        sta last_was_horizontal
        lda #1
        sta last_was_vertical

        jmp done_scrolling
.)


.(
+vscroll_do_down_scroll
        lda vcnt
        cmp #$7
        ; do color ram copy stage 2
        beq vswap_swap

        cmp #$0
        beq copy_color_ram

        cmp #$5
        bpl vswap_prepare_swap

        sec
        lda #$4
        sbc vcnt
        tax

        lda vcnt
        sta $d020

        ; cases 1,2,3,4
        lda fasteps_lo, x
        sta sc_w_dl+1
        clc
        adc #40
        sta sc_w_sl+1   
        lda fasteps_hi, x
        sta sc_w_dh+1
        adc #0
        sta sc_w_sh+1
        jsr sc_wrapper
        jmp done_scrolling

vswap_prepare_swap
        cmp #$5
        bne vswap_two
        jsr copy_to_swap_stage_1
        jmp done_scrolling
vswap_two
        jsr copy_to_swap_stage_2
        jmp done_scrolling

vswap_swap
        jsr swap_banks
        jmp done_scrolling

copy_color_ram
        ; not implemented
        lda #0
        sta last_was_horizontal
        lda #1
        sta last_was_vertical
        jmp done_scrolling
.)
;=====================================================================================================================


sc_wrapper
        clc
        lda swap_addr
sc_w_sl adc #$20
        sta sc_s+1
        lda swap_addr+1
sc_w_sh adc #$3
        sta sc_s+2

        clc
        lda swap_addr
sc_w_dl adc #$21
        sta sc_d+1

        lda swap_addr+1
sc_w_dh adc #$3
        sta sc_d+2
        jsr screen_copy
        rts

sc_b_wrapper
         clc
         lda swap_addr
sc_wb_sl adc #$21
         sta sc_b_s+1
         lda swap_addr+1
sc_wb_sh adc #$3
         sta sc_b_s+2

         clc
         lda swap_addr
sc_wb_dl adc #$20
         sta sc_b_d+1

         lda swap_addr+1
sc_wb_dh adc #$3
         sta sc_b_d+2
         jsr screen_copy_back
         rts

;=====================================================================================================================
hscroll
        ldx hcnt
hs_copy_when_shifted_to
        cpx #$8
        beq hscroll_copy
        jmp set_hscroll

hscroll_copy
        lda #$5
        sta $d020

        lda #$0
        cmp going_right
        beq move_cam_left ; going left

move_cam_right: ; going right
        inc viewport_x
        jmp hs_copy_from_top_screen

        ; shift the screen left, by copying from the current view to the current view address + 1
move_cam_left:
        dec viewport_x

        ; memcopy_from_h( swap, getslot_ptr(viewport_x, viewport_y + offset), viewport_x % 40 )
hs_copy_from_top_screen
        ; take the last line from the corresponding screen, which can
        ; be found by getting the current screen slot and then applying
        ; the offset needed.
        ldy viewport_y
        ldx viewport_x

        lda #1
        cmp going_right
        beq skip_getslot_dex
        cmp last_was_vertical
        beq skip_getslot_dex
        dex
skip_getslot_dex
        txa
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
tblref5
        adc screen_tbl, x
        sta cc_s+1
        lda imod25times40+1, y
tblref6
        adc screen_tbl+1, x
        sta cc_s+2

        ; calculate source offset (top screen)
        ldx viewport_x
        
  ;      lda last_was_vertical
  ;      cmp #1
  ;      bne top_copy_col
        ;dex
        dex

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
        dex ; TODO CHECK

        jsr getslot_ptr ; (viewport_x, viewport_y+24), returns in x, a
        
        ; calculate source base address (bottom screen)
        ldy viewport_x
        lda going_right
        cmp #0
        ;beq bottom_no_dey
        dey  ; TODO WTF
bottom_no_dey
        clc
        lda imod40, y
tblref7
        adc screen_tbl, x
        sta cc_s+1
        lda #0
tblref8
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
        lda #0
        cmp going_right
        beq set_hscroll
        stx hcnt
set_hscroll
        lda hcnt
        cmp #$08
        beq hscroll_skip_reg

        and #%00000111
        sta hcapped+1
        lda $d016 ; horizontal
        and #%11111000
hcapped ora #%11111111
        sta $d016  ; horizontal

hscroll_skip_reg
        lda #$1
        sta $d020

        cmp going_right
        bne hscroll_do_left_scroll
        jmp hscroll_do_right_scroll

.(
+hscroll_do_left_scroll
        lda hcnt    

        cmp #$8
        beq hswap_swap

        cmp #$1
        beq hswap_prepare_swap

        cmp #$2
        beq hswap_prepare_swap

        cmp #$7
        bne hextracases
        jmp copy_color_ram

hextracases
        ; cases 3,4,5,6
        lda hcnt
        sta $d020

        sec
        lda #$6
        sbc hcnt
        tax
        lda fasteps_lo, x
        sta sc_wb_sl+1
        clc
        adc #$1
        sta sc_wb_dl+1
        lda fasteps_hi, x
        sta sc_wb_dh+1
        sta sc_wb_sh+1
        jsr sc_b_wrapper
        jmp done_scrolling

hswap_prepare_swap
        ;lda #08
        ;sta $d020

        cmp #$1
        bne hswap_two
        jsr copy_to_swap_stage_1
        jmp done_scrolling
hswap_two
        jsr copy_to_swap_stage_2
        jmp done_scrolling

hswap_swap
        lda #08
        sta $d020

        lda #1
        cmp last_was_vertical
        bne hswap_do_swap
        cmp going_right
        beq hswap_do_swap
        
        ; WARNING, Recently patched, NO FUCKING IDEA.
        ;ldy viewport_y
        ;dey
        ;sty viewport_y

&debughere
;jmhere
;        inc cnter
;        lda cnter
;        cmp #$ff
;        bne jmhere
;        lda #$00
;        sta cnter
;        inc cnter2
;        lda cnter2
;        cmp #$c
;        bne jmhere
;        lda #$00
;        sta cnter
;        sta cnter2


        ;jsr swap_banks
        ;jsr copy_to_swap_stage_1
        ;jsr copy_to_swap_stage_2
       ; jsr swap_banks

        ;jsr swap_banks
        lda $d011 ; vertical
        and #%11111000
        sta $d011  ; vertical
        lda #$0
        sta hcnt
        jmp done_scrolling

hswap_do_swap
        jsr swap_banks
        lda #$0
        sta hcnt
        lda $d016 ; horizontal
        and #%11111000
        sta $d016  ; horizontal

        jmp done_scrolling

copy_color_ram
        ; not implemented
        lda #0
        sta last_was_vertical
        lda #1
        sta last_was_horizontal

        jmp done_scrolling
.)


.(
+hscroll_do_right_scroll
        lda hcnt
        cmp #$7
        ; do color ram copy stage 2
        beq hswap_swap

        cmp #$0
        beq copy_color_ram

        cmp #$5
        bpl hswap_prepare_swap

        sec
        lda #$4
        sbc hcnt
        tax

        lda hcnt
        sta $d020

        ; cases 1,2,3,4

        lda fasteps_lo, x
        sta sc_w_dl+1
        clc
        adc #$1
        sta sc_w_sl+1
        lda fasteps_hi, x
        sta sc_w_dh+1
        sta sc_w_sh+1
        jsr sc_wrapper
        jmp done_scrolling

hswap_prepare_swap
        cmp #$5
        bne hswap_two
        jsr copy_to_swap_stage_1
        jmp done_scrolling
hswap_two
        jsr copy_to_swap_stage_2
        jmp done_scrolling

hswap_swap
        jsr swap_banks
        jmp done_scrolling

copy_color_ram
        ; not implemented
        lda #0
        sta last_was_vertical
        lda #1
        sta last_was_horizontal

        jmp done_scrolling
.)
;=====================================================================================================================

done_scrolling

nocopy
nokey
        lda #$ef
        sta $dc00 ; up/down (W/S). it also gets the status of A.
        lda $dc01 ; read keyboard status
        cmp #$fe  
        bne check_f7
        lda #$3c
        cmp swap_addr+1
        beq skip_swap
        jmp do_swap
check_f7
        cmp #$f7
        bne skip_swap
        lda #$38
        cmp swap_addr+1
        beq skip_swap

do_swap
        jsr swap_banks
skip_swap


        lda #$7f
        sta $dc00 ; up/down (W/S). it also gets the status of A.
        lda $dc01 ; read keyboard status
        cmp #$fe  
        bne check_f7_hshift
        lda #$7
        cmp hmanualshift
        beq skip_hshift
        inc hmanualshift
        jmp do_hshift
check_f7_hshift
        cmp #$f7
        bne skip_hshift
        lda #$0
        cmp hmanualshift
        beq skip_hshift
        dec hmanualshift

do_hshift
        lda $d016 ; horizontal
        and #%11111000
        ora hmanualshift
        sta $d016  ; horizontal

skip_hshift
        lda #$fd
        sta $dc00 ; up/down (W/S). it also gets the status of A.
        lda $dc01 ; read keyboard status
        cmp #$fe  
        bne check_f7_vshift
        lda #$7
        cmp vmanualshift
        beq skip_vshift
        inc vmanualshift
        jmp do_vshift
check_f7_vshift
        cmp #$f7
        bne skip_vshift
        lda #$0
        cmp vmanualshift
        beq skip_vshift
        dec vmanualshift

do_vshift
        lda $d011 ; horizontal
        and #%11111000
        ora vmanualshift
        sta $d011  ; horizontal

skip_vshift

savea   lda #0
savex   ldx #0
savey   ldy #0
    
        lda #$00
        sta $d020
;        sta $d021

        lsr $d019 ; ack interrupt
        cli

finish
        rti


#include "parser/split/info.s"
vcnt .byt 7
hcnt .byt 7
hmanualshift .byt 7
vmanualshift .byt 7

#include "swap.s"
going_right .byt 1
going_down .byt 1
last_was_vertical .byt 1
last_was_horizontal .byt 1
fasteps_lo .byt $00, $fa, $f4, $ee
fasteps_hi .byt $00, $00, $01, $02
cnter .byt $00
cnter2 .byt $00
action_taken .byt $00

theend
