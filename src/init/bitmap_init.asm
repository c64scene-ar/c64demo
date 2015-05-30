// Init the bitmap loaded at $2000
// Use the screen ram at 0xc00 (0x400 is being used by text screen ram)

init_bitmap:
	ldx #$00
loaddccimage:
	lda $3f40,x // Charmem data (Scren ram)
	sta $0c00,x
	lda $4040,x
	sta $0d00,x
	lda $4140,x
	sta $0e00,x
	lda $4240,x
	sta $0f00,x

	lda $4328,x // Colormem data
	sta $d800,x
	lda $4428,x
	sta $d900,x
	lda $4528,x
	sta $da00,x
	lda $4628,x
	sta $db00,x
	inx
bne loaddccimage

	rts
