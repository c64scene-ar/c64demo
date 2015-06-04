; Spindle by lft, www.linusakesson.net/software/spindle/
; This is the code that executes inside the 1541.

; Memory
;
;  000	- Zero page; contains the gcr loop at $20
;  100	- Stack; used as block buffer
;  200	- communicate
;  300	- even gcr decoding table
;  400	- init 1, then serial table
;  500	- fetch
;  600	- init 2
;  700	- odd gcr decoding table

#define lax1c01 .byt $af, $01, $1c
#define sax .byt $87,
#define sbx0 .byt $cb, $00

got_sector	= $02
req_track	= $03
currtrack	= $04
ctrlseq		= $05
checksum	= $07

interested	= $08	; 22 bytes

ZPORG		= $20

sertable	= $400
eventable	= $300
oddtable	= $700

;---------------------- init 1 ------------------------------------------------

		*=$400
entry
		; load init 2

		lda	#18
		sta	$c
		lda	#2
		sta	$d
		lda	#3
		sta	$f9
		jsr	$d586	; read block into $600

		; load fetch

		lda	#18
		sta	$a
		lda	#11
		sta	$b
		lda	#2
		sta	$f9
		jsr	$d586	; read block into $500

		sei

		; device number jumpers treated as outputs so the register
		; bits always read back as zero

		lda	#$00
		sta	$1800
		lda	#$7a
		sta	$1802

		; copy zp code into place

		.(
		ldx	#zpcode_len - 1
loop
		lda	zpcodeblock,x
		sta	ZPORG,x
		dex
		bpl	loop
		.)

		; clear the set of sectors in which the host is interested

		.(
		lda	#0
		ldx	#20
loop
		sta	interested,x
		dex
		bpl	loop
		.)

		; read mode, SO enabled

		lda	#$ee
		sta	$1c0c

		jmp	init2
zpcodeblock
		*=ZPORG
zpc_loop
		; This nop is needed for the slow bitrates (at least for 00),
		; because apparently the third byte after a bvc sync might not be
		; ready at cycle 65 after all.

		; However, with the nop, the best case time for the entire loop
		; is 130 cycles, which leaves absolutely no slack for motor speed
		; variance at bitrate 11.

		; Thus, we modify the bne instruction at the end of the loop to
		; either include or skip the nop depending on the current
		; bitrate.

		nop

		lax1c01				; 62 63 64 65	44445555
		and	#$f0			; 66 67
		adc	#0			; 68 69		A <- C, also clears V
		tay				; 70 71
zpc_mod3	lda	oddtable		; 72 73 74 75	lsb = 00333330
		ora	eventable,y		; 76 77 78 79	y = 44440004, lsb = 00000000

		; first read in [0..25]
		; second read in [32..51]
		; third read in [64..77]
		; clv in [64..77]
		; in total, 80 cycles from zpc_b1

zpc_b2		bvc	zpc_b2			; 0 1

		pha				; 2 3 4		second complete byte (nybbles 3, 4)
zpc_entry
		lda	#$0f			; 5 6
		sax	zpc_mod5+1		; 7 8 9

		lax1c01				; 10 11 12 13	56666677
		and	#$80			; 14 15
		tay				; 16 17
		lda	#$03			; 18 19
		sax	zpc_mod7+1		; 20 21 22
		lda	#$7c			; 23 24
		sbx0				; 25 26

zpc_mod5	lda	oddtable,y		; 27 28 29 30	y = 50000000, lsb = 00005555
		ora	eventable,x		; 31 32 33 34	x = 06666600, lsb = 00000000
		pha				; 35 36 37	third complete byte (nybbles 5, 6)

		lax1c01				; 38 39 40 41	77788888
		clv				; 42 43
		and	#$1f			; 44 45
		tay				; 46 47

		; first read in [0..25]
		; second read in [32..51]
		; clv in [32..51]
		; in total, 48 cycles from b2

zpc_b1		bvc	zpc_b1			; 0 1

		lda	#$e0			; 2 3
		sbx0				; 4 5
zpc_mod7	lda	oddtable,x		; 6 7 8 9	x = 77700000, lsb = 00000077
		ora	eventable,y		; 10 11 12 13	y = 00088888, lsb = 00000000
		pha				; 14 15 16	fourth complete byte (nybbles 7, 8)

		lda	$1c01			; 17 18 19 20	11111222
		ldx	#$f8			; 21 22
		sax	zpc_mod1+1		; 23 24 25
		and	#$07			; 26 27
		tay				; 28 29
		ldx	#$c0			; 30 31

		lda	$1c01			; 32 33 34 35	22333334
		sax	zpc_mod2+1		; 36 37 38
		ldx	#$3e			; 39 40
		sax	zpc_mod3+1		; 41 42 43
		lsr				; 44 45		4 -> C

zpc_mod1	lda	oddtable		; 46 47 48 49	lsb = 11111000
zpc_mod2	ora	eventable,y		; 50 51 52 53	lsb = 22000000, y = 00000222
		pha				; 54 55 56	first complete byte (nybbles 1, 2)

		tsx				; 57 58
BNE_WITH_NOP	=	(zpc_loop - (* + 2)) & $ff
BNE_WITHOUT_NOP	=	(zpc_loop + 1 - (* + 2)) & $ff
zpc_bne		.byt	$d0,BNE_WITH_NOP	; 59 60 61	bne zpc_loop

		jmp	zp_return

zpcode_len	=	* - ZPORG

		.dsb	$500 - zpcodeblock - zpcode_len, $aa

;---------------------- init 2 ------------------------------------------------

		*=$600
init2
		; construct the gcr decoding tables

		.(
		ldx	#15
nybbleloop
		lda	gcrtable,x
		ldy	#4
bitloop
		sta	mod1+1
mod1		stx	eventable
		asl
		adc	#0
		sta	mod2+1
		txa
		asl
		asl
		asl
		asl
mod2		sta	oddtable
		lda	mod2+1
		asl
		adc	#0

		dey
		bne	bitloop

		dex
		bpl	nybbleloop
		.)
getcomm
		lda	#18
		sta	currtrack

		; load the communication code using the newly installed drivecode

		sta	req_track
		inc	interested+17
		jmp	drivecode_fetch
init_fetchret
		; verify the checksum

		.(
		ldx	#0
		txa
loop
		eor	$100,x
		inx
		bne	loop
		.)

		cmp	checksum
		bne	getcomm

		lda	#<fetch_return
		sta	mod_fetchret+1
		lda	#>fetch_return
		sta	mod_fetchret+2

		; The communication code is now on the stack page, so we move it.
		; We also build the serial table, overwriting init 1.

		.(
		ldx	#0
loop
		lda	$100,x
mod		sta	$200
		inc	mod+1
		txa
		sec
		ror
		lsr
		lsr
		sta	sertable,x
		dex
		bne	loop
		.)

		; now we prefetch the decruncher into the block buffer so the
		; stage1 program can be made as small as possible

		inc	interested+3
		jmp	drivecode_fetch

		; continues to fetch_return, entering the communication loop
gcrtable
		.byt	$0a
		.byt	$0b
		.byt	$12
		.byt	$13
		.byt	$0e
		.byt	$0f
		.byt	$16
		.byt	$17
		.byt	$09
		.byt	$19
		.byt	$1a
		.byt	$1b
		.byt	$0d
		.byt	$1d
		.byt	$1e
		.byt	$15

		.dsb	$700 - *, $bb

;---------------------- fetch -------------------------------------------------

		* = $500
drivecode_fetch
		; turn on led and motor

		lda	$1c00
		ora	#$0c
		sta	$1c00
seektrack
		.(
		ldx	currtrack
		cpx	req_track
		beq	bitrate
		bmi	seek_up
seek_down
		dex
		lda	#1
		sta	mod_seek+1
		bne	do_seek		; always
seek_up
		inx
		lda	#0
		sta	mod_seek+1
do_seek
		stx	currtrack

		ldy	#2
step
		lda	$1c00
mod_seek	eor	#0
		sec
		rol
		and	#3
		eor	$1c00
		sta	$1c00

		lda	#$99
		sta	$1c05
wait		lda	$1c05
		bmi	wait

		dey
		bne	step

		beq	seektrack	; always
bitrate
		ldy	#BNE_WITH_NOP
		lda	$1c00
		and	#$9f

		cpx	#31
		bcs	ratedone

		adc	#$20

		cpx	#25
		bcs	ratedone

		ldy	#BNE_WITHOUT_NOP
		adc	#$20

		cpx	#18
		bcs	ratedone

		adc	#$20
ratedone
		sta	$1c00
		sty	zpc_bne+1
		.)
fetchblock
		lda	#$2c	; bit
		sta	mod_divert

		lda	#$52
		sta	mod_id+1

		; wait for any header
nextheader
		ldx	#4	; will be 3 when entering the loop
		txs
waitsync
		bit	$1c00
		bmi	waitsync
		lda	$1c01	; ack the sync byte
		clv
		bvc	*
		lda	$1c01	; 11111222, which is 01010.010(01) for a header
		clv		; or 01010.101(11) for data
mod_id		cmp	#$52
		bne	waitsync

		bvc	*
		lda	$1c01	; 22333334
		clv
		ldx	#$01
		.byt	$8f,<(first_mod4+1), >(first_mod4+1)	; sax abs
		and	#$3e
		sta	first_mod3+1

		bvc	*
		lax1c01		; 44445555
		clv
		and	#$f0
		tay
first_mod4	lda	eventable,y
first_mod3	ora	oddtable
		pha

		bvc	*
		jmp	zpc_entry
zp_return
		lda	$1c01			; 64 65 66 67	44445555
		and	#$f0
		adc	#0			; A <- C, also clears V
		sta	last_mod4+1
		ldy	zpc_mod3+1
		lda	oddtable,y		; y = 00333330
last_mod4	ora	eventable		; lsb = 44440004

		; did we read a header or a data block?

mod_divert	jmp	have_data		; jmp / bit

		; does the host want this sector?

		ldx	$103
		ldy	interested,x
		beq	nextheader
		stx	got_sector

		; is the header checksum (in a) correct?

		eor	$104
		eor	$103
		eor	$102
		eor	$101
		bne	nextheader

		; then read the data

		ldx	#$4c			; jmp
		stx	mod_divert
		tax				; x = 0
		txs				; will be ff when entering the loop
		lda	#$55
		sta	mod_id+1
		jmp	waitsync
have_data
		sta	checksum

		; don't fetch the same block again later

		lda	#0
		ldx	got_sector
		sta	interested,x

mod_fetchret	jmp	init_fetchret		; changed to jmp fetch_return

		.dsb	$600 - *, $cc

;---------------------- communicate -------------------------------------------

		*=$200
fetch_return
		; turn off led

		lda	$1c00
		and	#$f7
		sta	$1c00
awaitcommand
		ldx	#$08
		stx	$1800	; pull clock to indicate that we're waiting for a command
waitforatn
		bit	$1800
		bpl	waitforatn	; make sure host is pulling atn

		lda	#$00
		sta	$1800		; release all lines

		; commands are:
		;	* Prepare for control sequence
		;		- Host releases atn with clock pulled
		;	* Fetch a block into the buffer
		;		- Host releases atn with data pulled
		;	* Transmit entire buffer
		;		- Host releases atn, keeps data and clock released
		;	* Request retransmission, fetch a(nother) block into the buffer.
		;		- Host releases atn with both clock and data pulled

waitfornatn
		ldx	$1800
		bmi	waitfornatn
		ldy	$1800

		beq	sendentry	; neither pulled
		cpy	#$01		; data pulled
		beq	fetchnext
		cpy	#$04		; clock pulled
		beq	controlseq
					; both pulled
		ldx	got_sector
		lda	#1
		sta	interested,x
fetchnext
		jmp	drivecode_fetch

		; transmit the buffer - first bit pair on the bus 38 cycles after atn released
sendloop
		bit	$1800
		bpl	*-3
		sta	$1800		; ---1g-h-	13 cycles after atn pulled, worst case
sendentry
		.byt	$bf,$00,$01	; lax $100,y
		and	#$0f

		; low nybble in a, high nybble (unmasked) in x

		bit	$1800
		bmi	*-3
		sta	$1800		; ---0a-b-	13 cycles after atn released, worst case

		asl
		ora	#$10

		bit	$1800
		bpl	*-3
		sta	$1800		; ---1c-d-	13 cycles after atn pulled, worst case

		lda	sertable,x	; 001gehf-
		ldx	#$0a

		bit	$1800
		bmi	*-3
		.byt	$8f,$00,$18	; ---0e-f-	sax $1800, 13 cycles after atn released, worst case

		lsr
		dey
		bne	sendloop

		bit	$1800
		bpl	*-3
		sta	$1800		; ---1g-h-	13 cycles after atn pulled, worst case

		; transmit checksum

		.byt	$a7, checksum	; lax zp
		and	#$0f

		; low nybble in a, high nybble (unmasked) in x

		bit	$1800
		bmi	*-3
		sta	$1800		; ---0a-b-	13 cycles after atn released, worst case

		asl
		ora	#$10

		bit	$1800
		bpl	*-3
		sta	$1800		; ---1c-d-	13 cycles after atn pulled, worst case

		lda	sertable,x	; 001gehf-
		ldx	#$0a

		bit	$1800
		bmi	*-3
		.byt	$8f,$00,$18	; ---0e-f-	sax $1800, 13 cycles after atn released, worst case

		lsr

		bit	$1800
		bpl	*-3
		sta	$1800		; ---1g-h-	13 cycles after atn pulled, worst case

		ldx	#$00

		bit	$1800		; wait for host to release atn after the transfer
		bmi	*-3

		stx	$1800		; release all lines

		jmp	awaitcommand
controlseq
		.(

		; The host will now transmit 28 bits on the transitions (both
		; edges) of atn. Data is transmitted over the clock line.
		; The 28 bits are 543210abcdefghijklmnopqrstu0 where
		; (543210) is the track number, msb first.
		; (abcdefghijklmnopqrstu) are the sector bits, starting with
		; sector 0. A set bit indicates that the host would like to
		; receive the sector.
		; (0) is a stop bit to get atn and clock back to released state.
		; The minimum time between clock transitions is 22 cycles, and
		; the data must not change within 7 cycles after a transition.

		ldx	#3
		ldy	#11
recvloop1
		lda	$1800
		bpl	*-3

		lsr
		lsr
		lsr
		rol	ctrlseq

		lda	$1800
		bmi	*-3

		lsr
		lsr
		lsr
		rol	ctrlseq

		dex
		bne	recvloop1
recvloop2
		lda	$1800
		bpl	*-3

		and	#4
		sta	interested,x
		inx

		lda	$1800
		bmi	*-3

		and	#4
		sta	interested,x
		inx

		dey
		bne	recvloop2
recvdone
		lda	ctrlseq		; this is the track number
		and	#$3f

		cmp	#36
		bcs	special

		sta	req_track
		jmp	drivecode_fetch
special
		cmp	#$3e		; 3e = reset drive
		bne	no_reset

		jmp	($fffc)
no_reset
		lda	$1c00		; 3f = stop motor
		and	#$fb
		sta	$1c00
		jmp	awaitcommand
		.)

		.dsb	$300 - *, $dd
