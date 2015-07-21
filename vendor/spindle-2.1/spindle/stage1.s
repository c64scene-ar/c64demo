; Spindle by lft, www.linusakesson.net/software/spindle/
; This is the small bootstrap program loaded by the kernal.

zp_dest		=	$f6

loaderorg	=	$0c00
sectorbuf	=	$0e00

		.word	basicstub
		*=$801
basicstub
		.(
		.word	end, 1
		.byt	$9e,"2061",0
end		.word	0
		.)
entry
		; Launch the drivecode

		.(
		ldx	#<command
		ldy	#>command
		lda	#command_end - command
		jsr	$ffbd

		lda	#15
		tay
		ldx	$ba
		bne	nodef
		ldx	#8
nodef
		jsr	$ffba

		jsr	$ffc0
		.)

		sei
		lda	#$35
		sta	1

		; Release the lines

		lda	#$3c
		sta	$dd02
		ldx	#0
		stx	$dd00

		; Turn off CIA interrupt

		lda	#$7f
		sta	$dc0d
		lda	$dc0d

		; While the drive is busy fetching drivecode, move the
		; loader into place

		.(
loop
		lda	loadersrc,x
		sta	loaderorg,x
		lda	loadersrc+$100,x
		sta	loaderorg+$100,x
		inx
		bne	loop
		.)

		; Wait for drive to signal MORE.

initialwait
		bit	$dd00
		bvc	initialwait
		bmi	initialwait

		; The first loadset may overwrite stage1, so
		; we have to return through the resident trampoline

		lda	#>(trampoline_clc-1)
		pha
		lda	#<(trampoline_clc-1)
		pha

		; Make the first loader call

		jmp	$c90

command
		; 23 bytes out of 42

		.(
		.byt	"M-E"
		.word	$205

		; Load first drivecode block into buffer 1 at $400
		lda	#18
		sta	$8
		lda	#12
		sta	$9
		lda	#1
		sta	$f9
		jsr	$d586

		jmp	$400
		.)
command_end

SHUF1		=	$04
SHUF2		=	$08-8
SHUF3		=	$00
SHUF4		=	$0c-8

DATA1		=	$02
CLOCK1		=	$08
DATA2		=	$01
CLOCK2		=	$04
DATA3		=	$10
CLOCK3		=	$40
DATA4		=	$20
CLOCK4		=	$80

loadersrc
		* = loaderorg

		.dsb	4, DATA3 | CLOCK3	; third bit pair is 00
		.dsb	4, DATA1 | CLOCK1	; first bit pair is 00
		.dsb	4, DATA2 | CLOCK2	; second bit pair is 00
		.dsb	4, DATA4 | CLOCK4	; fourth bit pair is 00

		; $0c10 -- entrypoint for installing a simple music player

		stx	irqmod+1
		sty	irqmod+2
		sei
		lda	#<irq
		sta	$fffe
		lda	#>irq
		sta	$ffff
		cli
		rts
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
irqmod
		jsr	0
		lsr	$d019

		pla
		sta	1
		pla
		tay
		pla
		tax
		pla
		rti

		.dsb	loaderorg+$40-*, $66

		.dsb	4, DATA3		; third bit pair is 01
		.dsb	4, DATA1		; first bit pair is 01
		.dsb	4, DATA2		; second bit pair is 01
		.dsb	4, DATA4		; fourth bit pair is 01

		; $0c50 -- internal entrypoint for stage 2 trampoline
trampoline
		sec
entryjmp
		jmp	!0			; operand modified by first loadset
trampoline_clc
		clc
		bcc	entryjmp
fieldtable

		.byt	%00000000	; 00, return -1 (handle match)
		.byt	%10000001	; 01, get literal length --> read one bit, goto 2/3

		.byt	%00000000	; 02, return 1
		.byt	%01000001	; 03, read two more bits, goto 4/5/6/7

		.byt	%11000000	; 04, read one more bit, add 2, return (2..3)
		.byt	%01100000	; 05, read two more bits, add 4, return (4..7)
		.byt	%00011000	; 06, read four more bits, add 8, return (8..23)
		.byt	%00000110	; 07, read six more bits, add 24, return (24..87)

offsettable
		.byt	$fe		; 00
		.byt	0		; 01

		.byt	$00		; 02
		.byt	0		; 03

		.byt	$7f+2		; 04
		.byt	$7f+4		; 05
		.byt	$7f+8		; 06
		.byt	$7f+24		; 07
end_of_stream
		beq	lastunit

		jmp	unitloop
lastunit
		lda	#$35
		sta	1
		jmp	mainloop

		.dsb	loaderorg+$80-*, $77

		.dsb	4, CLOCK3		; third bit pair is 10
		.dsb	4, CLOCK1		; first bit pair is 10
		.dsb	4, CLOCK2		; second bit pair is 10
		.dsb	4, CLOCK4		; fourth bit pair is 10

		; $0c90 -- entrypoint for the loader
loadfile
		; This is where the loadercall starts.

		bit	$dd00
		bvs	no_initial_eof		; WAIT/MORE -> proceed

		bmi	loadfile		; EOF1 -> stay here

		; EOF2 -> send ack, then proceed

		jsr	atnbrief
no_initial_eof
mainloop
		; Poll for the next block or EOF.

		bit	$dd00
		bvc	eof_detected

		bmi	mainloop		; WAIT -> no block yet

		; MORE -> request transmission
		jsr	atnbrief
		; First bit pair on the bus 40 cycles after atn pulled (13 cycles after released)
		.byt	$4b,0			; clear a and carry
		jmp	receive
eof_detected
		; Ack EOF2 immediately, in case this was the final loader call.

		bit	$dd00
		bmi	alldone

		; Send ack, then rts
atnbrief
		lda	#8
atnrelease
		sta	$dd00
		jsr	wait12
		eor	#8
		beq	atnrelease
alldone
wait12
		rts

		.dsb	loaderorg+$c0-*, $88

		.dsb	4, 0			; third bit pair is 11
		.dsb	4, 0			; first bit pair is 11
		.dsb	4, 0			; second bit pair is 11
		.dsb	4, 0			; fourth bit pair is 11

		; $0cd0
recvloop
		ldy	#0
		ldx	$dd00			; second bit pair
		sty	$dd00
		eor	loaderorg+SHUF2,x
		inc	mod_recvdest+1		; two cycles too much here
		ldy	#8
		ldx	$dd00			; third bit pair
		sty	$dd00
		eor	loaderorg+SHUF3,x
		ldy	#0
		cpy	mod_recvdest+1		; carry set if lsb == 0
		ldx	$dd00			; fourth bit pair
		sty	$dd00
		eor	loaderorg+SHUF4,x
mod_recvdest	sta	sectorbuf
receive						; clc before entering loop
		ldy	#8
		ldx	$dd00			; first bit pair
		sty	$dd00
		eor	loaderorg+SHUF1,x
		bcc	recvloop		; the page crossing is important

		; Receive checksum byte

		nop
		ldy	#0
		ldx	$dd00			; second bit pair
		sty	$dd00
		eor	loaderorg+SHUF2,x
		nop
		nop
		ldy	#8
		ldx	$dd00			; third bit pair
		sty	$dd00
		eor	loaderorg+SHUF3,x
		cmp	(0,x)
		ldx	$dd00			; fourth bit pair
		eor	loaderorg+SHUF4,x

		; z set if checksum ok

		beq	sumok

		ldy	#$30			; pull data and clock, release atn (nak)
		sty	$dd00
		jsr	wait12
		ldy	#$00
		sty	$dd00			; release all
		jmp	mainloop
sumok
		ldy	#$00
		sty	$dd00			; release all (ack)

		; Sector successfully received.

		.byt	$ab,0			; lax imm

		; Is this a meta block?

		sec
		rol	sectorbuf
		bcc	regularblock

		lda	#$80
		sta	sectorbuf+2
		lda	#2
regularblock
		sta	mod_getbit+1
unitloop
		dex
		lda	sectorbuf,x
		sta	zp_dest
		dex
		lda	sectorbuf,x
		bne	noshadow

		lda	#$34
		sta	1
		dex
		lda	sectorbuf,x
noshadow
		sta	zp_dest+1

		lda	#%10000001	; get literal length --> read one bit, goto 2/3
		clc
		bcc	bitloop
newbyte
		inc	mod_getbit+1
		;sec
bitloop
mod_getbit
		rol	sectorbuf
		beq	newbyte

		rol
		bcc	bitloop

		bmi	lookupdone

		tay
		lda	fieldtable,y
		beq	lookupdone

		clc
		bcc	bitloop
lookupdone
		;sec
		adc	offsettable,y
		bmi	gotmatch

		tay			; length
gotliteral
		dey
		sta	mod_sbx+1

		sec
		eor	#$ff
		adc	zp_dest
		sta	zp_dest
		bcs	noc1

		dec	zp_dest+1
noc1
		txa
mod_sbx
		.byt	$cb,0
		stx	mod_read+1

		cpy	#86		; max length - 1
readloop
mod_read
		lda	sectorbuf,y
		sta	(zp_dest),y
		dey
		bpl	readloop

		bcc	gotmatch	; selector bit not needed

		clc
		lda	#%10000000	; get selector bit --> read one bit, goto 0/1
		bcc	bitloop
gotmatch
		dex
		lda	sectorbuf,x
		and	#3
		beq	farmatch

		tay
		eor	#$ff
		;clc
		adc	zp_dest
		sta	zp_dest
		bcs	noc2

		dec	zp_dest+1
noc2
		lda	sectorbuf,x
		lsr
		lsr

		sec
setupcopy
		adc	zp_dest
		sta	mod_copy+1
		lda	zp_dest+1
		adc	#0
		sta	mod_copy+2
copyloop
mod_copy
		lda	!0,y
		sta	(zp_dest),y
		dey
		bpl	copyloop

		;clc
		lda	#%10000000	; get selector bit --> read one bit, goto 0/1
		bcc	bitloop
farmatch
		lda	sectorbuf,x
		lsr
		lsr
		cmp	#$3e
		bcc	not_end

		jmp	end_of_stream
not_end
		tay
		eor	#$ff
		;clc
		adc	zp_dest
		sta	zp_dest
		bcs	noc3

		dec	zp_dest+1
		sec
noc3
		dex
		lda	sectorbuf,x
		jmp	setupcopy
