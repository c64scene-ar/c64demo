; This is an example effect bundled with Spindle
; www.linusakesson.net/software/spindle/

#define PAGE	.dsb	$ff - ((* - 1) & $ff), $00

font		=	$3000
vm1		=	$3400
vm2		=	$3800

LOOPORG1	=	$fc00
LOOPORG2	=	$fd00

ptr1		=	$92
ypos		=	$94
time		=	$95
lastvalue	=	$96

BORDER		=	$fffd

		; memory
		;	3000-31ff	font
		;	3400-37ff	vm 1
		;	3800-3bff	vm 2
		;	8c00-		code
		;	fc00-fdff	speedcode

		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	prepare		; prepare routine
		.word	setup		; setup routine
		.word	interrupt	; irq handler
		.word	0		; main routine
		.word	0		; fadeout routine
		.word	cleanup		; cleanup routine
		.word	mod_jsr		; location of playroutine call

		.byt	"P",$30,$3b	; page range
		.byt	"P",$fc,$fd	; page range

		.byt	"Z",$90,$9f	; zero-page range

		.byt	0

		.word	loadaddr
		* = $8c00
loadaddr

prepare
		.(
		lda	#<LOOPORG1
		sta	ptr1
		lda	#>LOOPORG1
		sta	ptr1+1

		lda	#24
		sta	ypos
yloop
		ldy	#tem_size - 1
copy
		lda	template,y
		sta	(ptr1),y
		dey
		bpl	copy

		lda	ptr1
		clc
		adc	#tem_size
		sta	ptr1
		bcc	noc1
		inc	ptr1+1
noc1
		lda	tem_mod1+1
		clc
		adc	#40
		sta	tem_mod1+1
		bcc	noc2
		inc	tem_mod1+2
noc2
		dec	ypos
		bpl	yloop

		ldy	#0
		lda	#$60
		sta	(ptr1),y
		.)

		.(
		lda	#<vm2
		sta	tem_mod1+1
		lda	#>vm2
		sta	tem_mod1+2

		lda	#<LOOPORG2
		sta	ptr1
		lda	#>LOOPORG2
		sta	ptr1+1

		lda	#24
		sta	ypos
yloop
		ldy	#tem_size - 1
copy
		lda	template,y
		sta	(ptr1),y
		dey
		bpl	copy

		lda	ptr1
		clc
		adc	#tem_size
		sta	ptr1
		bcc	noc1
		inc	ptr1+1
noc1
		lda	tem_mod1+1
		clc
		adc	#40
		sta	tem_mod1+1
		bcc	noc2
		inc	tem_mod1+2
noc2
		dec	ypos
		bpl	yloop

		ldy	#0
		lda	#$60
		sta	(ptr1),y
		.)

		.(
		lda	#0
		tax
loop
		sta	vm1+$000,x
		sta	vm1+$100,x
		sta	vm1+$200,x
		sta	vm1+$300,x
		sta	vm2+$000,x
		sta	vm2+$100,x
		sta	vm2+$200,x
		sta	vm2+$300,x
		dex
		bne	loop
		.)

		rts
setup
		lda	#0
		sta	$d020
		sta	$d015

		.(
		tax
loop
		sta	$d800,x
		sta	$d900,x
		sta	$da00,x
		sta	$db00,x
		dex
		bne	loop
		.)

		lda	#$3c
		sta	$dd02
		lda	#$dc
		sta	$d018
		lda	#$5b
		sta	$d011
		lda	#$08
		sta	$d016

		lda	#$b
		sta	$d021
		lda	#$5
		sta	$d022
		lda	#$d
		sta	$d023
		lda	#$0
		sta	$d024

		lda	#$fb
		sta	$d012

		rts

		; A cleanup routine is typically added late in development,
		; while working on the transitions. In this case, the lft logo
		; coming up uses a raster interrupt at line $2e, and plays the
		; music towards the end of the video frame. This effect uses a
		; raster interrupt at line $fb and plays the music immediately,
		; then goes on with other stuff for 2/3 of the frame. During the
		; transition, we disable interrupts, wait for the bottom border,
		; call the playroutine once before switching to the next effect.
		; This ensures smooth playback.
cleanup
		.(
		sei
		bit	$d011
		bpl	*-3
		lda	mod_jsr+1
		sta	mod+1
		lda	mod_jsr+2
		sta	mod+2
mod		jsr	!0
		rts
		.)

interrupt
		dec	BORDER

		sta	int_savea+1
		stx	int_savex+1
		sty	int_savey+1

mod_jsr		bit	!0

		.(
swap1		lda	#$ec
		sta	$d018

		lda	#<(LOOPORG1 + tem_sbx + 1 - template)
		sta	mod+1
swap2		lda	#>LOOPORG1
		sta	mod+2
		lda	#0
		sta	lastvalue
		ldx	#24
yloop
		txa
		asl
		clc
		adc	#$30
		adc	time
		tay
		lda	sine,y

		tay
		eor	#$ff
		sec
		adc	lastvalue
		sty	lastvalue
mod		sta	!0
		lda	mod+1
		clc
		adc	#tem_size
		sta	mod+1
		bcc	noc1
		inc	mod+2
noc1
		dex
		bpl	yloop

		ldy	#39
xloop
		tya
		asl
		clc
		adc	time
		tax
		lda	sine,x
		adc	time
		adc	time
		tax
swap3		jsr	LOOPORG1
		dey
		bpl	xloop

		lda	swap1+1
		eor	#$ec ^ $dc
		sta	swap1+1

		lda	swap2+1
		eor	#>(LOOPORG1 ^ LOOPORG2)
		sta	swap2+1
		sta	swap3+2

		inc	time
		.)

int_savea	lda	#0
int_savex	ldx	#0
int_savey	ldy	#0
		lsr	$d019
		inc	BORDER
		rti
template
tem_sbx		.byt	$cb,0	; sbx
		txa
tem_mod1	sta	vm1,y
tem_size	= * - template

		PAGE
sine
		.bin	0,0,"sine.bin"
