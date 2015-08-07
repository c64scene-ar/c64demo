		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	0		; prepare routine
		.word	setup		; setup routine
		.word	interrupt	; irq handler
		.word	0		; main routine
		.word	0		; fadeout routine
		.word	0		; cleanup routine
		.word	0		; location of playroutine call

		; tags go here

		;.byt	"P",$04,$07	; range of pages in use
		;.byt	"I",$10,$1f	; range of pages inherited
		;.byt	"Z",$02,$03	; range of zero-page addresses in use
		;.byt	"X"		; avoid loading
		;.byt	"M",<play,>play	; install music playroutine

		.byt	"S"		; i/o safe
		.byt	0		; end of tags

		.word	loadaddr
		* = $3000
loadaddr

setup
		;lda	#$3d
		;sta	$dd02
		lda	#0
		sta	$d015
		sta	$d017
		sta	$d01b
		sta	$d01c
		sta	$d01d

                lda     $d011
                and     #%10000000
                sta     $d011

		lda	#$00
		sta	$d012
                lda #$00
                sta $d021
		rts

interrupt
	sta	int_savea+1
	stx	int_savex+1
	sty	int_savey+1

	lda #<irq_stable	; +2, 2
	ldx #>irq_stable	; +2, 4
	sta $fffe		; +4, 8
	stx $ffff		; +4, 12
	inc $d012		; +6, 18
	asl $d019		; +6, 24
nop
	tsx			; +2, 26
	cli			; +2, 28
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop

irq_stable
	txs			; +2, 9~10
nop

	; 42 cycles

	ldx #$08		; +2, 11~12
	dex			; +2 * 8, 27~28
	bne *-1			; +3 * 7, +2, 50~51
	bit $00			; +3, 53~54

	lda $d012		; +4, 57~58
	cmp $d012		; +4, 61~62
	beq *+2			; +2/+3, 64



		; effect goes here
                ldx #$16
preloop
                dex       ; 2
                bne preloop  ; 4
                nop
                nop
                nop

                lda #$05
                sta $d021
                sta $d020


rasterline
                ldx #$09  ; ciclo 0
loop
                dex       ; 2
                bne loop  ; 4
                
                nop
                and $00
                and $00

newa            lda #$01
                sta $d021
                sta $d020
                inc newa+1

                ldx $d012
                lda #%10000000
                and $d011
                beq loop
                ldx #$ff
 
                jmp loop 


	lda #<interrupt	; +2, 2
	ldx #>interrupt	; +2, 4
	sta $fffe		; +4, 8
	stx $ffff		; +4, 12

        lda #$30
        sta $d012

int_savea	lda	#0
int_savex	ldx	#0
int_savey	ldy	#0
	
		lsr	$d019
		rti

