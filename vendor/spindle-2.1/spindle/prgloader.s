; Spindle by lft, www.linusakesson.net/software/spindle/
; Simple loader for pef2prg.

count	=	$02
src	=	$04
dest	=	$06

		* = $801 - 2
		.word	header
header
		.(
		.word	end, 1
		.byt	$9e,"2061",0
end		.word	0
		.)
start
		sei
		lda	#$34
		sta	1

		ldx	#0
chunkloop
		lda	efo+18,x
		sta	count
		lda	efo+19,x
		sta	count+1
		ora	count
		beq	done

		lda	efo+20,x
		clc
		adc	#<efo
		sta	src
		lda	efo+21,x
		adc	#>efo
		sta	src+1

		lda	efo+22,x
		sta	dest
		lda	efo+23,x
		sta	dest+1

		ldy	count
		beq	aligned
		dey
		beq	bytedone
byteloop
		lda	(src),y
		sta	(dest),y
		dey
		bne	byteloop
bytedone
		lda	(src),y
		sta	(dest),y
aligned
		lda	count+1
		beq	pagedone
pages
		dec	src+1
		dec	dest+1
		dey
pageloop
		lda	(src),y
		sta	(dest),y
		dey
		bne	pageloop

		lda	(src),y
		sta	(dest),y

		dec	count+1
		bne	pages
pagedone
		txa
		clc
		adc	#6
		tax
		jmp	chunkloop
done
		inc	1

		lda	#$00
		sta	$dd00
		lda	#$3c
		sta	$dd02

		lda	#$7f
		sta	$dc0d
		lda	$dc0d

		.bin	0,0,"commonsetup.bin"

		jsr	v_prepare
		jsr	v_setup

		lda	efo+8
		sta	$fffe
		lda	efo+9
		sta	$ffff

		ora	efo+8
		beq	mainloop

		lsr	$d019
		cli
mainloop
		jsr	v_main

		lda	#$ff
		sta	$dc02
		lsr
		sta	$dc00
		lda	#$10
		bit	$dc01
		bne	mainloop
fadeloop
		jsr	v_main
		jsr	v_fadeout
		bcc	fadeloop

		jsr	v_cleanup
		jmp	*
v_prepare
		lda	efo+4
		ora	efo+5
		beq	skip
		jmp	(efo+4)
v_setup
		lda	efo+6
		ora	efo+7
		beq	skip
		jmp	(efo+6)
v_main
		lda	efo+10
		ora	efo+11
		beq	skip
		jmp	(efo+10)
v_fadeout
		lda	efo+12
		ora	efo+13
		beq	skip
		jmp	(efo+12)
v_cleanup
		lda	efo+14
		ora	efo+15
		beq	skip
		jmp	(efo+14)
skip
		rts
efo
