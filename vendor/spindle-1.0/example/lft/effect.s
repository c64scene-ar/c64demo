; This is an example effect bundled with Spindle
; www.linusakesson.net/software/spindle/

#define PAGE	.dsb	$ff - ((* - 1) & $ff), $00

texthi		=	$3e00
textlo		=	$3f00

timer		=	$03
ypos		=	$04	; [0,75]

count1		=	$10
siney		=	$11

INTLINE		=	$2e
FLDMIN		=	16

BORDER		=	$fffd

		; memory
		;	2800-2fff	code
		;	3e00-3fff	generated textures
		;	4000-ffff	bitmaps, vms, speedcode

		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	prepare		; prepare routine
		.word	setup		; setup routine
		.word	interrupt	; irq handler
		.word	main		; main routine
		.word	0		; fadeout routine
		.word	0		; cleanup routine
		.word	mod_jsr		; location of playroutine call

		.byt	"P",$3e,$3f	; page range
		.byt	"P",$7c,$7f	; page range
		.byt	"P",$bc,$bf	; page range
		.byt	"P",$dc,$df	; page range
		.byt	"Z",$03,$11	; zp range
		.byt	"S"		; i/o safe

		.byt	0

		.word	loadaddr
		* = $2800
loadaddr

setup
		lda	#0
		sta	$d020
		sta	$d021
		sta	$d015

		lda	#$38
		sta	$d011

		lda	#$18
		sta	$d016

		lda	#INTLINE
		sta	$d012

		rts
prepare
		lda	#75
		sta	timer
		sta	ypos
		rts
main
		.(
		ldy	#19*13-1
		sty	index+1

		lda	#12
		sta	count1
yloop
		lda	count1
		clc
phasey		adc	#0
		tay
		lda	sine256,y
		sta	siney

		ldx	#18
xloop
		txa
		clc
phasex		adc	#0
		tay
		lda	sine256,y

		clc
		adc	siney

		lsr

		and	#$f

index		ldy	#0
		ora	logo,y

		tay
		lda	palette,y

		ldy	index+1

		sta	textlo,y
		asl
		asl
		asl
		asl
		sta	texthi,y

		dec	index+1

		dex
		bpl	xloop

		dec	count1
		bpl	yloop

		inc	phasey+1
		dec	phasex+1
		.)

		rts
palette
		.dsb	16,0
		.byt	$b,$c,$5,$5,$f,$d,$d,$1
		.byt	$1,$d,$d,$f,$5,$5,$c,$b

		PAGE
interrupt
		.(
		; cycle 10..16

		sta	int_savea+1		; 10
		stx	int_savex+1		; 14
		sty	int_savey+1		; 18

		lda	1			; 22
		sta	int_save1+1		; 25

		lda	#$35			; 29
		sta	1			; 31

		ldy	ypos			; 34

		ldx	offs_screen,y		; 37

		lda	screens+0,x		; 41
		sta	$dd02			; 45
		lda	screens+1,x		; 49
		sta	$d018			; 53

		lda	screens+3,x		; 57
		beq	nocrunch		; 61

		nop				; 63
		jsr	delay32			; 2

		ldx	#10			; 34
		lda	#$79			; 36
crunchloop
		jsr	delay24			; 38
		sta	$d011			; 62	linecrunch
		clc				; 3
		adc	#1			; 5
		and	#7			; 7
		ora	#$78			; 9
		jsr	delay22			; 11
		dex				; 33
		bne	crunchloop		; 35

		jmp	didcrunch		; 37
nocrunch
		lda	0			; 1, line before scheduled badline
		jsr	delay34			; 4
		lda	#$39			; 38
didcrunch
		ldx	offs_fld,y		; 40, before scheduled badline
fldloop
		sta	$d011			; 43, fld
		clc				; 47
		adc	#1			; 49
		and	#7			; 51
		ora	#$38			; 53
		jsr	delay46			; 55
		dex				; 38
		bne	fldloop			; 40

		.(
		lda	$d012			; 42
		clc
		adc	#79
		bcs	sat
		cmp	#$d1
		bcc	nosat
sat
		lda	#$d1
nosat
wait
		cmp	$d012
		bcs	wait
		.)

		ora	#$40
		sta	$d011

		inc	timer
		ldx	timer
		cpx	#76 * 2
		bne	nowrap
		ldx	#0
nowrap
		stx	timer
		cpx	#76
		bcc	nomirror

		lda	#76 * 2 - 1
		sec
		sbc	timer
		tax
nomirror
		stx	ypos

		lda	#$e0
wait
		cmp	$d012
		bcs	wait

		dec	BORDER

		.(
		ldy	ypos
		ldx	offs_screen,y
		lda	screens+2,x
		sta	mod+2
		ldx	offs_start,y
		dec	BORDER
mod		jsr	!0
		inc	BORDER
		.)

		inc	BORDER

		lda	#$38
		sta	$d011
		.)

mod_jsr		bit	!0

		asl	$d019
int_save1	lda	#0
		sta	1
int_savea	lda	#0
int_savex	ldx	#0
int_savey	ldy	#0
		rti

delay63		jmp	delay60
delay60		nop
delay58		nop
delay56		nop
delay54		nop
delay52		nop
delay50		nop
delay48		nop
delay46		nop
delay44		nop
delay42		nop
delay40		nop
delay38		nop
delay36		nop
delay34		nop
delay32		nop
delay30		nop
delay28		nop
delay26		nop
delay24		nop
delay22		nop
delay20		nop
delay18		nop
delay16		nop
delay14		nop
delay12		rts

		PAGE
logo
#include "logo.i"

		PAGE
#include "sine.i"

offs_screen
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2

		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
		.byt	$04 << 2
		.byt	$05 << 2
		.byt	$00 << 2
		.byt	$01 << 2
		.byt	$02 << 2
		.byt	$03 << 2
offs_fld
		.byt	FLDMIN + ($00 << 1) + 10
		.byt	FLDMIN + ($01 << 1)
		.byt	FLDMIN + ($02 << 1) + 10
		.byt	FLDMIN + ($03 << 1)
		.byt	FLDMIN + ($04 << 1) + 10
		.byt	FLDMIN + ($05 << 1)
		.byt	FLDMIN + ($06 << 1) + 10
		.byt	FLDMIN + ($07 << 1)
		.byt	FLDMIN + ($08 << 1) + 10
		.byt	FLDMIN + ($09 << 1)
		.byt	FLDMIN + ($0a << 1) + 10
		.byt	FLDMIN + ($0b << 1)
		.byt	FLDMIN + ($0c << 1) + 10
		.byt	FLDMIN + ($0d << 1)
		.byt	FLDMIN + ($0e << 1) + 10
		.byt	FLDMIN + ($0f << 1)
		.byt	FLDMIN + ($10 << 1) + 10
		.byt	FLDMIN + ($11 << 1)
		.byt	FLDMIN + ($12 << 1) + 10
		.byt	FLDMIN + ($13 << 1)
		.byt	FLDMIN + ($14 << 1) + 10
		.byt	FLDMIN + ($15 << 1)
		.byt	FLDMIN + ($16 << 1) + 10
		.byt	FLDMIN + ($17 << 1)
		.byt	FLDMIN + ($18 << 1) + 10
		.byt	FLDMIN + ($19 << 1)
		.byt	FLDMIN + ($1a << 1) + 10
		.byt	FLDMIN + ($1b << 1)
		.byt	FLDMIN + ($1c << 1) + 10
		.byt	FLDMIN + ($1d << 1)
		.byt	FLDMIN + ($1e << 1) + 10
		.byt	FLDMIN + ($1f << 1)
		.byt	FLDMIN + ($20 << 1) + 10
		.byt	FLDMIN + ($21 << 1)
		.byt	FLDMIN + ($22 << 1) + 10
		.byt	FLDMIN + ($23 << 1)

		.byt	FLDMIN + ($24 << 1) + 10
		.byt	FLDMIN + ($25 << 1)
		.byt	FLDMIN + ($26 << 1) + 10
		.byt	FLDMIN + ($27 << 1)
		.byt	FLDMIN + ($28 << 1) + 10
		.byt	FLDMIN + ($29 << 1)
		.byt	FLDMIN + ($2a << 1) + 10
		.byt	FLDMIN + ($2b << 1)
		.byt	FLDMIN + ($2c << 1) + 10
		.byt	FLDMIN + ($2d << 1)
		.byt	FLDMIN + ($2e << 1) + 10
		.byt	FLDMIN + ($2f << 1)
		.byt	FLDMIN + ($30 << 1) + 10
		.byt	FLDMIN + ($31 << 1)
		.byt	FLDMIN + ($32 << 1) + 10
		.byt	FLDMIN + ($33 << 1)
		.byt	FLDMIN + ($34 << 1) + 10
		.byt	FLDMIN + ($35 << 1)
		.byt	FLDMIN + ($36 << 1) + 10
		.byt	FLDMIN + ($37 << 1)
		.byt	FLDMIN + ($38 << 1) + 10
		.byt	FLDMIN + ($39 << 1)
		.byt	FLDMIN + ($3a << 1) + 10
		.byt	FLDMIN + ($3b << 1)
		.byt	FLDMIN + ($3c << 1) + 10
		.byt	FLDMIN + ($3d << 1)
		.byt	FLDMIN + ($3e << 1) + 10
		.byt	FLDMIN + ($3f << 1)
		.byt	FLDMIN + ($40 << 1) + 10
		.byt	FLDMIN + ($41 << 1)
		.byt	FLDMIN + ($42 << 1) + 10
		.byt	FLDMIN + ($43 << 1)
		.byt	FLDMIN + ($44 << 1) + 10
		.byt	FLDMIN + ($45 << 1)
		.byt	FLDMIN + ($46 << 1) + 10
		.byt	FLDMIN + ($47 << 1)
		.byt	FLDMIN + ($48 << 1) + 10
		.byt	FLDMIN + ($49 << 1)
		.byt	FLDMIN + ($4a << 1) + 10
		.byt	FLDMIN + ($4b << 1)
offs_start
		.dsb	6,19*0
		.dsb	6,19*1
		.dsb	6,19*2
		.dsb	6,19*3
		.dsb	6,19*4
		.dsb	6,19*5

		.dsb	6,(19*6) & $ff
		.dsb	6,(19*7) & $ff
		.dsb	6,(19*8) & $ff
		.dsb	6,(19*9) & $ff
		.dsb	6,(19*10) & $ff
		.dsb	6,(19*11) & $ff
		.dsb	6,(19*12) & $ff
screens
		; dd02, d018, code_msb, crunchflag
		.byt	$3d, $f8, $40, $00
		.byt	$3d, $f8, $50, $01
		.byt	$3e, $f8, $80, $00
		.byt	$3e, $f8, $90, $01
		.byt	$3f, $70, $e0, $00
		.byt	$3f, $70, $f0, $01
