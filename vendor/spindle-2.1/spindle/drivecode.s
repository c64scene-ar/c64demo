; Spindle by lft, www.linusakesson.net/software/spindle/
; This code executes inside the 1541.

; Memory
;
;  000	- Zero page; contains the gcr loop at $30-$91
;  100	- Stack; used as block buffer
;  200	- Code for serial communication
;  300	- GCR decoding table for even nybbles
;  400	- Init 1, then serial bit shuffling table
;  500	- Code for fetching data from disk
;  600	- Init 2 and code for serial communication
;  700	- GCR decoding table for odd nybbles

#define lax1c01 .byt $af, $01, $1c
#define sax .byt $87,
#define sbx0 .byt $cb, $00

got_sector	= $00
req_track	= $01
currtrack	= $02
checksum	= $03

nextsideid	= $12	; 3 bytes
command		= $15	; 3 bytes

interested	= $18	; 21 bytes
ninterested	= $2d

ZPORG		= $30

sertable	= $400
eventable	= $300
oddtable	= $700

;---------------------- Init 1 ------------------------------------------------

		*=$400
entry
		; Load init 2

		lda	#18
		sta	$c
		lda	#2
		sta	$d
		lda	#3
		sta	$f9
		jsr	$d586	; Read block into $600

		; Load fetch

		lda	#18
		sta	$a
		lda	#11
		sta	$b
		lda	#2
		sta	$f9
		jsr	$d586	; Read block into $500

		sei

		; Device number jumpers treated as outputs so the register
		; bits always read back as zero.

		lda	#$00
		sta	$1800		; Release all lines to indicate WAIT
		lda	#$7a
		sta	$1802

		; Copy zp code into place

		.(
		ldx	#zpcode_len - 1
loop
		lda	zpcodeblock,x
		sta	ZPORG,x
		dex
		bpl	loop
		.)

		; Clear the set of sectors that the host is interested in

		.(
		lda	#0
		ldx	#21	; Also clear ninterested
loop
		sta	interested,x
		dex
		bpl	loop
		.)

		; Read mode, SO enabled

		lda	#$ee
		sta	$1c0c

		; Construct the GCR decoding tables

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

		; Load the communication code using the
		; newly installed drivecode

		sta	req_track
		inc	interested+17
		jmp	drivecode_fetch
init_fetchret
		; Verify the checksum

		.(
		ldx	#0
		txa
loop
		eor	$100,x
		inx
		bne	loop
		.)

		eor	checksum
		bne	getcomm

		sta	interested+17

		jmp	init2

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

;---------------------- Init 2 ------------------------------------------------

		*=$600
init2
		; The communication code is now on the stack page, so we move
		; it. We also build the serial table, overwriting init 1.

		.(
		ldx	#0
		ldy	#0
loop
		lda	$100,x
		sta	$200,y
		iny
		txa
		sec
		ror
		lsr
		lsr
		sta	sertable,x
		dex
		bne	loop
		.)

		; Initialisation complete.

		jmp	load_first

flip_fetchret
		; Verify the checksum.

		.(
		ldx	#0
		txa
loop
		eor	$100,x
		inx
		bne	loop
		.)

		cmp	checksum
		beq	flipsumok
flipagain
		jmp	seektrack
flipsumok
		; Do the knock codes match?

		lda	$107
		eor	nextsideid+2
		bne	flipagain

		lda	$108
		eor	nextsideid+1
		bne	flipagain

		lda	$109
		eor	nextsideid+0
		bne	flipagain

		sta	interested+17

		; Host has made the last regular loadcall. We have transferred
		; those blocks and signalled EOF1. The piggybacked command
		; specified a flip. We have waited until the correct disk is in
		; the drive, and we are ready to fetch a block in the first
		; chunk. But the host might not even have made the flip
		; loadercall yet, and we're still sending EOF1 for the earlier
		; call.

		; Stop the motor, go to EOF2 and wait for ack.

		lda	$1c00
		and	#$fb
		sta	$1c00

		ldx	#$00

		lda	#$0a
		sta	$1800

		bit	$1800
		bpl	*-3

		bit	$1800
		bmi	*-3

		; Keep signalling EOF2, to make the flip loadercall ack and
		; return.

		bit	$1800
		bpl	*-3

		bit	$1800
		bmi	*-3

		; Now go to WAIT while we fetch the first block from the
		; new disk side.

		stx	$1800
load_first
		; Sector buffer contains the communication code for the new
		; disk side. It is stored backwards, but not eor-transformed.
		; At the end we find the first load command, as well as the
		; knock code for the next side.

		.(
		ldx	#6
		ldy	#0
loop
		lda	$100,x
		sta	nextsideid,y
		iny
		dex
		bne	loop
		.)

		lda	#<fetch_return
		sta	mod_fetchret+1
		lda	#>fetch_return
		sta	mod_fetchret+2

		lda	#1
		sta	req_track
nextcommand
		.(
		ldy	#0

		ldx	#7
		lda	command+2
loop1
		lsr
		bcc	not1

		inc	interested+13,x
		iny
not1
		dex
		bpl	loop1

		ldx	#7
		lda	command+1
loop2
		lsr
		bcc	not2

		inc	interested+5,x
		iny
not2
		dex
		bpl	loop2

		ldx	#4
		lda	command
loop3
		lsr
		bcc	not3

		inc	interested,x
		iny
not3
		dex
		bpl	loop3
		.)

		sty	ninterested
		cpy	#0
		bne	nospecial

		lsr
		bcc	noreset

		ldx	#$08
		lda	#$0a
		stx	$1800	; EOF1 (prevent accidental MORE)
		sta	$1800	; EOF2

		bit	$1800
		bpl	*-3

		bit	$1800
		bmi	*-3

		jmp	($fffc)
noreset
		; Flip detection

		lda	#<flip_fetchret
		sta	mod_fetchret+1
		lda	#>flip_fetchret
		sta	mod_fetchret+2
		lda	#18
		sta	req_track
		inc	interested+17
		lda	#$08
		sta	$1800	; EOF1
		lda	#$04
		jmp	fetch_no_led
nospecial
		lsr
		bcc	nonewtrack

		ldx	req_track
		inx
		cpx	#18
		bne	not18

		inx
not18
		stx	req_track
nonewtrack
		lsr
		bcc	noeof1

		lda	#$08
		sta	$1800	; EOF1
noeof1
		jmp	drivecode_fetch

		.dsb	$700 - *, $bb

;---------------------- Fetch -------------------------------------------------

		* = $500
drivecode_fetch
		; Turn on LED and motor

		lda	#$0c
fetch_no_led
		ora	$1c00
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

		; Wait for any header
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

		; Did we read a header or a data block?

mod_divert	jmp	have_data		; jmp / bit

		; Does the host want this sector?

		ldx	$103
		ldy	interested,x
		beq	nextheader

		stx	got_sector

		; Is the header checksum (in a) correct?

		eor	$104
		eor	$103
		eor	$102
		eor	$101
		bne	nextheader

		; Then read the data

		ldx	#$4c			; jmp
		stx	mod_divert
		tax				; x = 0
		txs				; will be ff when entering the loop
		lda	#$55
		sta	mod_id+1
		jmp	waitsync
have_data
		sta	checksum

mod_fetchret	jmp	init_fetchret		; changed to jmp fetch_return

		.dsb	$600 - *, $cc

;---------------------- Communicate -------------------------------------------

		*=$200
fetch_return
		; Turn off LED.

		lda	$1c00
		and	#$f7
		sta	$1c00

		ldx	#$02

		lda	$1800		; Are we in EOF1?
		beq	awaitcommand

		; Yes, turn off motor, go to EOF2 and wait for ack.

		lda	$1c00
		and	#$fb
		sta	$1c00

		lda	#$0a
		sta	$1800

		bit	$1800
		bpl	*-3

		bit	$1800
		bmi	*-3
awaitcommand
		stx	$1800		; Indicate MORE
waitforatn
		bit	$1800
		bpl	waitforatn	; Make sure host is pulling atn

		; Warm up the motor for the next block.

		lda	$1c00
		ora	#$04
		sta	$1c00

		ldy	#0
		beq	sendentry	; always

		; Transmit the buffer - first bit pair on the bus 40 cycles
		; after atn pulled
sendloop
		bit	$1800
		bpl	*-3
		sta	$1800		; ---1g-h-	13 cycles after atn pulled, worst case
sendentry
		.byt	$bf,$00,$01	; lax $100,y
		and	#$0f

		; Low nybble in a, high nybble (unmasked) in x

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

		; Transmit the checksum

		.byt	$a7, checksum	; lax zp
		and	#$0f

		; Low nybble in a, high nybble (unmasked) in x

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

		bit	$1800		; Wait for host to release atn after the transfer
		bmi	*-3

		stx	$1800		; Release all lines to indicate WAIT

		lda	$1800		; Read ack status 10-17 cycles after atn edge

		and	#$05
		beq	gotack

		jmp	drivecode_fetch
gotack
		ldx	got_sector
		sta	interested,x

		; We have an ack, so we can trust the buffer contents.
		; Partially decode the eor-transformation to see if the
		; next command is piggybacked here.
		; host	transfer #	drive	func
		; 00	ff		01	checksum
		; 01	00		00	buf[00]
		; 02	01		ff	buf[ff] ^ buf[00]

		lda	checksum
		bpl	nopiggyback

		sta	command
		lda	$100
		sta	command+1
		eor	$1ff
		sta	command+2
nopiggyback
		dec	ninterested
		bne	nonewcommand

		jmp	nextcommand
nonewcommand
		jmp	drivecode_fetch

		.dsb	$300 - 9 - *, $dd

		; These are modified when the disk image is created.
sideid
		.byt	0,0,0		; Knock code for this disk side
		.byt	$4c,$46,$54	; Knock code for next disk side
initcommand
		.byt	$80,$00,$00	; Initial block set
