; Spindle by lft, www.linusakesson.net/software/spindle/
; Prepare CIA #1 timer B to compensate for interrupt jitter.
; Also initialise d01a and dc02.
; This code is inlined into prgloader, and also into the
; first effect driver by pefchain.

		ldx	$d012
		inx
resync
		cpx	$d012
		bne	*-3
		; at cycle 4 or later
		ldy	#0		; 4
		sty	$dc07		; 6
		lda	#62		; 10
		sta	$dc06		; 12
		iny			; 16
		sty	$d01a		; 18
		dey			; 22
		dey			; 24
		sty	$dc02		; 26
		cmp	(0,x)		; 30
		cmp	(0,x)		; 36
		cmp	(0,x)		; 42
		lda	#$11		; 48
		sta	$dc0f		; 50
		txa			; 54
		inx			; 56
		inx			; 58

		cmp	$d012		; 60	still on the same line?
		bne	resync
