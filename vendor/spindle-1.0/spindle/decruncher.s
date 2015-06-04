; Spindle by lft, www.linusakesson.net/software/spindle/
; A simple, small and fast decruncher.
; Fits inside one page, expects the crunched data in the following page.

DECRUNCHER	=	$0e00

CRUNCHBUF	=	DECRUNCHER + $100

bitshifter	=	$f0
npiece		=	$f1
unpackptr	=	$f2	; word

		* = DECRUNCHER
decrunch
		.(
		; decrunch from CRUNCHBUF to whatever address is specified in the block

		lda	#$80
		sta	bitshifter
		asl
		sta	mod_getbit+1
		lda	#3
		sta	mod_getbyte+1

		lda	CRUNCHBUF+0
		sta	unpackptr
		lda	CRUNCHBUF+1
		sta	unpackptr+1
		lda	CRUNCHBUF+2
		sta	npiece
got_literal
		ldy	#3
		jsr	getfield
		tay
		tax
litloop
mod_getbyte	lda	CRUNCHBUF,y
		sta	(unpackptr),y
		dey
		bpl	litloop

		dec	npiece
		beq	all_done

		txa
		sec
		adc	mod_getbyte+1
		sta	mod_getbyte+1

		txa
		sec
		adc	unpackptr
		sta	unpackptr
		bcc	no_carry

		inc	unpackptr+1
no_carry
		cpx	#7
		bcc	got_copy
nextpiece
		ldy	#1
		jsr	getfield
		lsr
		bcs	got_literal
got_copy
		ldy	mod_getbyte+1
		inc	mod_getbyte+1

		.byt	$bf,0,>CRUNCHBUF	; lax abs,y
		and	#$1f			; get offset field
		bne	nobigoffs

		ldy	#7
		jsr	getfield
		adc	#$20
nobigoffs
		eor	#$ff
		sec
		adc	unpackptr
		sta	mod_src+1
		lda	unpackptr+1
		adc	#$ff
		sta	mod_src+2

		txa				; get length field
		lsr
		lsr
		lsr
		lsr
		lsr
		bne	nobiglength

		ldy	#5
		jsr	getfield
		adc	#8
nobiglength
		sta	mod_len+1

		ldy	#$ff
copyloop
		iny
mod_src		lda	!0,y
		sta	(unpackptr),y
mod_len		cpy	#0	; the parameter will be length - 1
		bne	copyloop

		dec	npiece
		beq	all_done

		tya
		sec
		adc	unpackptr
		sta	unpackptr
		bcc	nextpiece

		inc	unpackptr+1
		jmp	nextpiece
all_done
		rts
getfield
		lda	#0
fieldloop
		asl	bitshifter
		beq	newbyte
gotbyte
		rol
		dey
		bne	fieldloop

		;clc
		rts
newbyte
		sta	mod_savea+1
		dec	mod_getbit+1
mod_getbit	lda	CRUNCHBUF
		;sec
		rol
		sta	bitshifter
mod_savea	lda	#0
		jmp	gotbyte
		.)

		.dsb	(DECRUNCHER + $c0) - *, 0

; Some space left in the page, so we put the blank filler effect here.

		.bin	0,0,"blankfiller.bin"

; Still some space left, so pefchain puts the first filespec here.
