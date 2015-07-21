; This is an example effect bundled with Spindle
; www.linusakesson.net/software/spindle/
; Feel free to display the Spindle logo in your own demo, if you like.

vm	=	$a400

INTLINE	=	$fb

		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	0		; prepare routine
		.word	setup		; setup routine
		.word	0		; irq handler
		.word	0		; main routine
		.word	0		; fadeout routine
		.word	0		; cleanup routine
		.word	0		; location of playroutine call

		.byt	"S"		; i/o safe
		.byt	"X"		; avoid loading (better to load while music plays)

		.byt	"I",$04,$07	; inherit the basic screen

		.byt	0

		.word	loadaddr
		* = $a000
loadaddr
		.bin	0,0,"graphics.bin"
setup
		lda	#0
		sta	$d020
		sta	$d021
		sta	$d011

		lda	#$3e
		sta	$dd02

		lda	#$1b
		sta	$d011
		lda	#$08
		sta	$d016
		lda	#$98
		sta	$d018

		lda	#$3
		sta	$d027
		sta	$d028

		lda	#24+6*8+9
		sta	$d000
		sta	$d002
		lda	#$32+10*8+33
		sta	$d001
		lda	#$32+10*8+54
		sta	$d003

		lda	#$03
		sta	$d015
		lda	#0
		sta	$d010
		sta	$d017
		sta	$d01c
		sta	$d01d

		lda	#$f
		ldx	#0
		ldy	#4
loop
mod1		lda	vm,x
		cmp	#64 + 26
		lda	#$1
		bcs	bigtext
		lda	#$f
bigtext
mod2		sta	$d800,x
		dex
		bne	loop

		inc	mod1+2
		inc	mod2+2
		dey
		bne	loop

		rts
