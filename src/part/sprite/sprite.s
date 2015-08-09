SCREEN_WIDTH = 320
SCREEN_HEIGHT = 200
SCREEN_RIGHT_BORDER_WIDTH = 24
SCREEN_TOP_BORDER_HEIGHT = 30
SPRITE_HALF_WIDTH = 6
SPRITE_HALF_HEIGHT = 10

CHAR_BACKGROUND_COLOR = $00
CHAR_MULTICOLOR_1 = $0b
CHAR_MULTICOLOR_2 = $01
CHAR_COLOR = $0f

CENTER_X = ((SCREEN_WIDTH / 2) + SCREEN_RIGHT_BORDER_WIDTH - SPRITE_HALF_WIDTH)
CENTER_Y = ((SCREEN_HEIGHT / 2) + SCREEN_TOP_BORDER_HEIGHT - SPRITE_HALF_HEIGHT)

TOTAL_FRAMES = 6
SPEED = 3
NUM_SPRITES = 8


; efo header

.byte "EFO2"       ; fileformat magic
.word 0            ; prepare routine
.word setup        ; setup routine
.word interrupt    ; irq handler
.word 0            ; main routine
.word 0            ; fadeout routine
.word 0            ; cleanup routine
.word 0            ; location of playroutine call

; tags go here

;.byte "P",$04,$07    ; range of pages in use
;.byte "I",$10,$1f    ; range of pages inherited
.byte "Z",$02,$03    ; range of zero-page addresses in use
;.byte "X"        ; avoid loading
;.byte "M",<play,>play    ; install music playroutine

.byte "S"        ; i/o safe
.byte 0        ; end of tags

.word loadaddr

* = $c000
loadaddr:

setup:
    lda #$3c          ; VIC bank $0000 - $3fff
    sta $dd02

    jsr init_screen   ; clear the screen
    jsr init_sprite   ; enable sprite

    lda #$00
    sta $d012

    rts

interrupt:
    sta int_savea+1
    stx int_savex+1
    sty int_savey+1

    jsr move_sprites
    jsr update_sprite_positions
    jsr animate_sprites

    asl $d019
int_savea: lda #0
int_savex: ldx #0
int_savey: ldy #0
    rti


init_screen: .(
    ldx #$00
    stx $d021     ; set background color
    stx $d020     ; set border color
loop:
    lda #$20      ; #$20 is the spacebar Screen Code
    ; TODO Use constant SCREEN_RAM + offset
    sta $0400, x  ; fill four areas with 256 spacebar characters
    sta $0500, x
    sta $0600, x
    sta $06e8, x

    lda #$01      ; set foreground to black in Color RAM
    ; TODO Use constant SCREEN_RAM + offset
    sta $d800, x
    sta $d900, x
    sta $da00, x
    sta $dae8, x

    inx
    bne loop
    rts
.)

init_sprite:
    lda #%11111111  ; enable all sprites
    sta $d015

    lda #%11111111  ; set multicolor mode for all sprites
    sta $d01c

    lda #%00000000  ; all sprites have priority over background
    sta $d01b

    ; set shared colors
    lda #CHAR_BACKGROUND_COLOR
    sta $d021
    lda #CHAR_MULTICOLOR_1
    sta $d025
    lda #CHAR_MULTICOLOR_2
    sta $d026

    ; set color for all sprites
    lda #CHAR_COLOR
    sta $d027
    sta $d028
    sta $d029
    sta $d02a
    sta $d02b
    sta $d02c
    sta $d02d
    sta $d02e

    rts

move_sprites: .(
    lda #1
    sta temp
    ldx #0
loop:
    clc
    lda speed_y, x
    adc pos_y, x
    sta pos_y, x

    ; TODO Use constants
    cmp #48             ; check hit at top
    beq invert_speed_y
    ; TODO Use constants
    cmp #230            ; check hit at bottom
    bne done_y
invert_speed_y:
    lda speed_y, x
    eor #$ff            ; negate(a) = invert(a) + 1  (two's complement)
    sec
    adc #0
    sta speed_y, x
done_y:

    clc
    lda speed_x, x
    bpl pos
neg:
    adc pos_x, x
    sta pos_x, x
    bcs check_left_x
    beq toggle_bit
pos:
    adc pos_x, x
    sta pos_x, x
    bcc check_left_x
toggle_bit:
    lda pos_x_h         ; if pos_x overflows, invert 8th bit
    eor temp
    sta pos_x_h
check_left_x:
    ; TODO Use constants
    cmp #24             ; check hit at left
    bne check_right_x
    lda pos_x_h
    and temp
    beq invert_speed_x
check_right_x:
    ; TODO Use constants
    cmp #64             ; check hit at right
    bne done_x
    lda pos_x_h
    and temp
    beq done_x
invert_speed_x:
    lda speed_x, x
    eor #$ff
    sec
    adc #0
    sta speed_x, x
done_x:
    inx
    asl temp
    bne loop
    rts
.)

update_sprite_positions: .(
    ldx #0
    ldy #0
loop:
    lda pos_x, x
    sta $d000, y
    lda pos_y, x
    sta $d001, y
    iny
    iny
    inx
    cpx #NUM_SPRITES
    bne loop

    lda pos_x_h          ; update bit#8 of x-coordinate of all sprites
    sta $d010
    rts
.)

animate_sprites: .(
    dec cur_iter
    bne done
    lda #SPEED
    sta cur_iter

    ldx cur_frame
    inx
    txa
    cmp #TOTAL_FRAMES
    bne render
    lda #0
render:
    sta cur_frame
    ; TODO Use constants
    adc #$80
    sta $07f8
    sta $07f9
    sta $07fa
    sta $07fb
    sta $07fc
    sta $07fd
    sta $07fe
    sta $07ff
done:
    rts
.)


cur_frame: .byte 0
cur_iter:  .byte SPEED
pos_x:     .byte CENTER_X, CENTER_X+16, CENTER_X-10, CENTER_X+12, CENTER_X+23, CENTER_X-5, CENTER_X-34, CENTER_X+3
pos_y:     .byte CENTER_Y, CENTER_Y+4, CENTER_Y+12, CENTER_Y-4, CENTER_Y-25, CENTER_Y-10, CENTER_Y+30, CENTER_Y-14
pos_x_h:   .byte 0
speed_x:   .byte $01, $ff, $01, $02, $ff, $02, $01, $ff
speed_y:   .byte $ff, $02, $01, $ff, $ff, $02, $02, $01

; FIXME
* = $0002
temp: .byte 0
