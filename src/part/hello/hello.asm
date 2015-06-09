		// efo header

		.byte	"EFO2"		// fileformat magic
		.word	0		// prepare routine
		.word	setup		// setup routine
		.word	interrupt	// irq handler
		.word	main		// main routine
		.word	0		// fadeout routine
		.word	0		// cleanup routine
		.word	0		// location of playroutine call

		// tags go here

		//.byt	"P",$04,$07	// range of pages in use
		//.byt	"I",$10,$1f	// range of pages inherited
		//.byt	"Z",$02,$03	// range of zero-page addresses in use
		//.byt	"S"		// i/o safe
		//.byt	"X"		// avoid loading
		//.byt	"M",<play,>play	// install music playroutine

		.byt	0

		.word	loadaddr
		* = $3000
loadaddr

setup
		lda	#$30
		sta	$d012
		rts
interrupt
		// nominal sync code with no sprites:
		sta	int_savea+1	// 10..16
		lda	$dc06		// in the range 1..7
		eor	#7
		sta	*+4
		bpl	*+2
		lda	#$a9
		lda	#$a9
		lda	$eaa5

		// at cycle 35

		stx	int_savex+1
		sty	int_savey+1

		// effect goes here

int_savea	lda	#0
int_savex	ldx	#0
int_savey	ldy	#0
		lsr	$d019
		rti

main:
	ldx #$01     // set X to zero (black color code)
loop:
	inx
	stx $d021    // set background color
	stx $d020    // set border color
	jmp loop