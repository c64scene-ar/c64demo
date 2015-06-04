; Spindle by lft, www.linusakesson.net/software/spindle/
; Blank filler effect.
; Beware of hardcoded offsets in pefchain.c

irq
	pha
	txa
	pha
	tya
	pha
	lda	1
	pha
	lda	#$35
	sta	1
	bit	!0
	lsr	$d019
	pla
	sta	1
	pla
	tay
	pla
	tax
	pla
	rti

setup
	lda	#0
	sta	$d020
	sta	$d011
	sta	$d015
	lda	#$f0
	sta	$d012
	rts
