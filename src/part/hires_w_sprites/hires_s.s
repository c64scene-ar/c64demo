		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	0		; prepare routine
		.word	setup		; setup routine
		.word	swap_start	; irq handler
		.word	0		; main routine
		.word	0		; fadeout routine
		.word	0		; cleanup routine
		.word	0		; location of playroutine call

		; tags go here

		;.byt	"P",$04,$07	; range of pages in use
		;.byt	"I",$10,$1f	; range of pages inherited
		;.byt	"Z",$02,$03	; range of zero-page addresses in use
		;.byt	"X"		; avoid loading
		;.byt	"M",<play,>play	; install music playroutine

		.byt	"S"		; i/o safe
		.byt	0		; end of tags

		.word	loadaddr
		* = $3000
loadaddr

setup
	;	lda	#$3d
	;	sta	$dd02

        lda #$00
		sta	$d017
		sta	$d01b
		sta	$d01c
		sta	$d01d
		lda	#$30
		sta	$d012

	lda #$3b ;enable bitmap mode
	sta	$d011

	lda	#$3d ;vic base address = $4000 (SpindleV2)
	sta	$dd02

	lda #$48 ;video matrix = 5000, bitmap base = 6000
	sta	$d018

	lda	#0
	sta	$d020
	sta	$d021

	lda	#$ff ;enable sprites
	sta	$d015

        ; PVM patch
        ; hires singlecolor.. w00t?
        lda     $d016
        and     %11101111
        sta     $d016
        

	lda #$f1
	sta $d01a

	lda $dc0d
	lda $dd0d
	asl $d019

	cli
        rts

return

        ; pla
	; tay
	; pla
	; tax
	; pla

int_savea       lda     #0
int_savex       ldx     #0
int_savey       ldy     #0
int_saves       ldx     #0
                txs

	;clear interrupt register
        lsr  $d019

	rti

sprite_ptrs = $53f8


swap_start
    sta     int_savea+1
    stx     int_savex+1
    sty     int_savey+1
    tsx
    stx     int_saves+1

swap_24:
    lda #0
    sta $d010
;    lda #0
    sta sprite_ptrs + 0
    lda #107
    sta $d000
    lda #73
    sta $d001
    lda #15
    sta $d027
    lda #1
    sta sprite_ptrs + 1
    lda #44
    sta $d002
    lda #95
    sta $d003
    lda #10
    sta $d028
    lda #2
    sta sprite_ptrs + 2
    lda #80
    sta $d004
    lda #102
    sta $d005
    lda #15
    sta $d029
    lda #6
    sta sprite_ptrs + 6
    lda #120
    sta $d00c
    lda #109
    sta $d00d
    lda #2
    sta $d02d
    lda #5
    sta sprite_ptrs + 5
    lda #48
    sta $d00a
    lda #114
    sta $d00b
    lda #9
    sta $d02c
    lda #4
    sta sprite_ptrs + 4
    lda #69
    sta $d008
    lda #114
    sta $d009
    lda #15
    sta $d02b
    lda #3
    sta sprite_ptrs + 3
    lda #64
    sta $d006
    lda #114
    sta $d007
    lda #10
    sta $d02a
    lda #7
    sta sprite_ptrs + 7
    lda #122
    sta $d00e
    lda #125
    sta $d00f
    lda #15
    sta $d02e
    ;
    lda #130
    sta $d012
    lda #<swap_130
  ;  sta $314
    sta $ffff
    lda #>swap_130
    sta $fffe
 ;   sta $315
    jmp return

swap_130:
    lda #8
    sta sprite_ptrs + 0
    lda #80
    sta $d000
    lda #133
    sta $d001
    lda #9
    sta sprite_ptrs + 1
    lda #104
    sta $d002
    lda #149
    sta $d003
    lda #3
    sta $d028
    lda #11
    sta sprite_ptrs + 6
    lda #96
    sta $d00c
    lda #157
    sta $d00d
    lda #15
    sta $d02d
    lda #10
    sta sprite_ptrs + 2
    lda #135
    sta $d004
    lda #165
    sta $d005
    ;
    lda #207
    sta $d012
    lda #<swap_207
;    sta $314

    sta $ffff


    lda #>swap_207

    sta $fffe
    ;sta $315
    jmp return

swap_207:
    lda #107
    sta $d00e
    lda #73
    sta $d00f
    lda #107
    sta $d00c
    lda #73
    sta $d00d
    lda #107
    sta $d00a
    lda #73
    sta $d00b
    lda #15
    sta $d02c
    lda #107
    sta $d008
    lda #73
    sta $d009
    lda #107
    sta $d006
    lda #73
    sta $d007
    lda #15
    sta $d02a
    lda #107
    sta $d004
    lda #73
    sta $d005
    lda #13
    sta sprite_ptrs + 1
    lda #48
    sta $d002
    lda #210
    sta $d003
    lda #15
    sta $d028
    lda #12
    sta sprite_ptrs + 0
    lda #73
    sta $d000
    lda #210
    sta $d001
    ;
    lda #24
    sta $d012
    lda #<swap_24
    ;sta $314

    sta $ffff
    lda #>swap_24
   ; sta $315

    sta $ffff
    jmp return

