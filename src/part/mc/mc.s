		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	0		; prepare routine
		.word	setup		; setup routine
		.word	0		; irq handler
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
		lda	#$3d
		sta	$dd02
		lda	#0
		sta	$d015
		sta	$d017
		sta	$d01b
		sta	$d01c
		sta	$d01d
		lda	#$30
		sta	$d012

	lda     $D016 ;enable multicolor
	ora     #$10
	sta     $D016

	lda     #$BB ;enable bitmap mode
	sta     $D011

	lda     #$16 ;vic base = $4000
	sta     $DD00

	lda     #$08 ; video matrix = 4000, bitmap base = 6000
	sta     $D018

        lda     #0
	sta     $D020
	lda     #15
	sta     $D021
;
; memcpy((void*)0xd800, (void*)0x2000, 0x400);
;
	ldx	#0
memcpy
	lda	$2000, x
	sta	$d800, x
	lda	$2100, x
	sta	$d900, x
	lda	$2200, x
	sta	$da00, x
	lda	$2300, x
	sta	$db00, x
	dex
	bne	memcpy

        rts

