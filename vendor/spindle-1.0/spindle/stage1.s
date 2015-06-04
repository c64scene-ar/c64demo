; Spindle by lft, www.linusakesson.net/software/spindle/
; This is a minimal (two blocks) bootstrap program loaded by the kernal.
; It contains the c64 side of the fastloader, but not the decruncher.

loaderorg	=	$0c00
DECRUNCHER	=	$0e00

loadtemp	=	$f4
zp_zero		=	$f5
load_n		=	$f6
load_tracks	=	$f7

ENTRYVECTOR	=	DECRUNCHER + $ec
FILETABLE	=	DECRUNCHER + $ee

CRUNCHBUF	=	DECRUNCHER + $100

		.word	basicstub
		*=$801
basicstub
		.(
		.word	end, 1
		.byt	$9e,"2061",0
end		.word	0
		.)
entry
		; launch the drivecode

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

		; release the lines

		lda	#$3c
		sta	$dd02
		ldx	#0
		stx	$dd00

		stx	zp_zero

		; turn off cia interrupt

		lda	#$7f
		sta	$dc0d
		lda	$dc0d

		; while the drive is busy fetching drivecode, move the
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

		; the drive has prefetched the decruncher,
		; so we simply request what's in the buffer

		jsr	recv_and_check

		inc	mod_recvdest+2	; change from >DECRUNCHER to >CRUNCHBUF

		lda	FILETABLE
		ldx	#<(FILETABLE + 1)
		ldy	#>(FILETABLE + 1)
		jsr	loadcompressed

		jmp	(ENTRYVECTOR)
command
		; 23 bytes out of 42

		.(
		.byt	"M-E"
		.word	$205

		; load first drivecode block into buffer 1 at $400
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

SHUF1		=	$34
SHUF2		=	$38-8
SHUF3		=	$30
SHUF4		=	$3c-8

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

loadcompressed
		; pointer to file table in y:x
		; a is nnnnnnni where
		;	n is length of file table and
		;	i is set if we have to load below the i/o area

		stx	sbp_mod+1
		sty	sbp_mod+2
		ldx	#>DECRUNCHER
		lsr
		sta	load_tracks
		bcc	noshadow

		ldx	#>shadowdecrunch
noshadow
		stx	j_decrunch1+2
		stx	j_decrunch2+2

		lda	#0
loadnexttbl
		pha
		tax

		lda	#$18		; clock is pulled => control sequence
		jsr	sendcmd
		jsr	wait12
		jsr	wait12

		ldy	#6		; 6 bits of track number
		jsr	sendbytepart
		jmp	loadcont

		.dsb	loaderorg+$30-*, $66

		.dsb	4, DATA3 | CLOCK3	; third bit pair is 00
		.dsb	4, DATA1 | CLOCK1	; first bit pair is 00
		.dsb	4, DATA2 | CLOCK2	; second bit pair is 00
		.dsb	4, DATA4 | CLOCK4	; fourth bit pair is 00

		; jumptable at loaderorg + $40
		jmp	special_request
loadcont
		lda	#0
		sta	load_n
		jsr	sendbytepart	; 8 sector bits
		jsr	sendbytepart	; 8 sector bits
		ldy	#6
		jsr	sendbytepart	; 5 sector bits and 1 stop bit
		jmp	loadloop_entry
loadloop
		lda	#$28		; data is pulled => fetch block
		jsr	sendcmd

j_decrunch1	jsr	DECRUNCHER
loadloop_entry
		jsr	recv_and_check

		dec	load_n
		bne	loadloop

j_decrunch2	jsr	DECRUNCHER

		pla
		clc
		adc	#4

		dec	load_tracks
		bne	loadnexttbl

		rts

		.dsb	loaderorg+$70-*, $77

		.dsb	4, DATA3		; third bit pair is 01
		.dsb	4, DATA1		; first bit pair is 01
		.dsb	4, DATA2		; second bit pair is 01
		.dsb	4, DATA4		; fourth bit pair is 01
starttransfer
		; first bit pair on the bus 38 cycles after atn released

		lda	#$08	; data and clock are released => transfer
sendcmd
		; a = 08 for transfer, 28 for fetch, 18 for control, 38 for retransmit

		; wait for drive to be ready for a command (clock pulled)

		bit	$dd00
		bvs	*-3

		; pull atn for at least 8 cycles

		sta	$dd00
		nop
		and	#$f7
		sta	$dd00		; release atn
		lsr	zp_zero		; delay 5 cycles
		rts

sendbytepart
		; x = offset in filetable
		; y = number of bits

		lda	#$00
sbp_loop
		and	#$08
sbp_mod		asl	!0,x
		.(
		bcc	notset1
		ora	#$10
		inc	load_n
notset1
		sta	$dd00		; update clock line
		;nop
		eor	#$08
		sta	$dd00		; pull/release atn

		dey
		bne	sbp_loop

		inx
		ldy	#8
		rts
		.)

		.dsb	loaderorg+$b0-*, $88

		.dsb	4, CLOCK3		; third bit pair is 10
		.dsb	4, CLOCK1		; first bit pair is 10
		.dsb	4, CLOCK2		; second bit pair is 10
		.dsb	4, CLOCK4		; fourth bit pair is 10
recv_and_check
		.(
again
		jsr	wait18
		lda	#0
		sta	$dd00			; release all lines
		jsr	starttransfer
		.byt	$4b, 0			; asr #0, clear a and c
		nop
		jsr	wait12
		jsr	receive
		beq	checksumok

		lda	#$38
		jsr	sendcmd
		jmp	again
checksumok
		rts
		.)
recvtail
		eor	loaderorg+SHUF3,x
		nop
		ldy	#0
		ldx	$dd00			; fourth bit pair
		sty	$dd00			; release all lines
		eor	loaderorg+SHUF4,x

		; z set if checksum ok

		; atn must be kept released until at least 31 cycles after
		; previously being set

		rts

		.dsb	loaderorg+$f0-*, $99

		.dsb	4, 0			; third bit pair is 11
		.dsb	4, 0			; first bit pair is 11
		.dsb	4, 0			; second bit pair is 11
		.dsb	4, 0			; fourth bit pair is 11
shadowdecrunch
		dec	1
		jsr	DECRUNCHER
		inc	1
		rts
recvloop
		ldy	zp_zero
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
mod_recvdest	sta	DECRUNCHER
receive						; clc before entering loop
		ldy	#8
		ldx	$dd00			; first bit pair
		sty	$dd00
		eor	loaderorg+SHUF1,x
		bcc	recvloop

		; receive checksum byte

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
		jmp	recvtail
special_request
		; accumulator selects function
		; fc = stop motor, f8 = reset drive

		.(
		sta	loadtemp

		lda	#$18		; clock is pulled => control sequence
		jsr	sendcmd
		jsr	wait30

		ldy	#28
		lda	#$00
loop
		and	#$08
		asl	loadtemp
		bcc	zero
		ora	#$10
zero
		sta	$dd00		; update clock line
		eor	#$08
		sta	$dd00		; pull/release atn

		dey
		bne	loop

		rts
		.)
wait30
		jsr	wait12
wait18
		cmp	(0,x)
wait12
		rts
loader_end
