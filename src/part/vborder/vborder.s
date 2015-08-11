		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	0		; prepare routine
		.word	setup		; setup routine
		.word	interrupt	; irq handler
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
		* = $c000
loadaddr

setup
		lda	#$3d
		sta	$dd02
		lda	#0
		sta	$d015
		sta	$d017
		sta	$d01b
		sta	$d01c
		sta	$d01d

                lda     $d018
                and     #%00000111
                ora     #%00001000
                sta     $d018

		lda	#$f9
		sta	$d012

		lda	$d011
                and     #%01111111
		sta	$d011

        lda     #$3B ;enable bitmap mode
        sta     $D011

        lda     #$18
        sta     $d016

                lda #$00
                sta $d021

                lda #$01
                sta $d020


        ; COPY 3c00-3fff to d800-dbff
        ldy #$04
        ldx #$00
ll:     lda $8000,x
        sta $d800,x    ; copy color RAM data
        inx
        bne ll
        inc ll+2
        inc ll+5
        dey
        bne ll
        ; COPY done

; lda #$00
; sta $3fff

;		lsr	$d019
		rts

interrupt
	sta	int_savea+1
	stx	int_savex+1
	sty	int_savey+1

        lda $d011
        and #$f7
        sta $d011

	lda	#$ff
	sta	$d012

        lda #<irq2        ; +2, 2
        ldx #>irq2        ; +2, 4
        sta $fffe               ; +4, 8
        stx $ffff               ; +4, 12
       
int_savea	lda	#0
int_savex	ldx	#0
int_savey	ldy	#0
	
		lsr	$d019
                cli
		rti


irq2

	sta	int_savea_i2+1
	stx	int_savex_i2+1
	sty	int_savey_i2+1

        lda $d011
        ora #$08
        sta $d011

        jsr $1200

	lda	#$f9
	sta	$d012

        lda #<interrupt        ; +2, 2
        ldx #>interrupt        ; +2, 4
        sta $fffe               ; +4, 8
        stx $ffff               ; +4, 12



int_savea_i2	lda	#0
int_savex_i2	ldx	#0
int_savey_i2	ldy	#0

		lsr	$d019
                cli
		rti
	


