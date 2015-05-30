//============================================================
// write the two line of text to screen center
//============================================================


init_text:
	ldx #$28          // iterate $28 times (40 cols)
loop_text:
	lda line1,x      // read characters from line1 table of text...
	///sta $0590,x      // ...and store in screen ram near the center
	sta $0658,x      // ...and store in screen ram near the center
	lda line2,x      // read characters from line1 table of text...
	sta $06a8,x
	//sta $05e0,x      // ...and put 2 rows below line1

	dex
	bne loop_text    // loop if we are not done yet
	rts
