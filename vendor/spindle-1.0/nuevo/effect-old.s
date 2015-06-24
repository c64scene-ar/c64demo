		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	prepare		; prepare routine
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
		;.byt	"S"		; i/o safe
		;.byt	"X"		; avoid loading
		;.byt	"M",<play,>play	; install music playroutine

		.byt	0

		.word	loadaddr

		* = $c000
loadaddr

prepare
                .(
                ldy     #$00
setup_buffer
        //      Estos eran los LDA originales. como estamos pintando nosotros,
        //      entonces los LDA originales que se vayan a cagar.
        //      resula que en este modo, lo que va en screen ram es el color (single color) :)
        // 	lda     $3f40,Y
	//	lda     $4040,Y
	//	lda     $4140,Y
	//	lda     $4240,Y
                lda     #$02
         	sta     $c00,Y
		sta     $d00,Y
		sta     $e00,Y
		sta     $f00,Y
		iny
		bne     setup_buffer
                .)

                .(
                ldy     #$00
setup_buffer
                lda     #$05
         	sta     $400,Y
		sta     $500,Y
		sta     $600,Y
		sta     $700,Y
		iny
		bne     setup_buffer
                .)

         
                lda     #$00
                ldx     #$00
clearcolor
                sta     $D800,x
                sta     $D900,x
                sta     $DA00,x
                sta     $DB00,x
                inx
                bne     clearcolor



setup
		lda	#$00  // set irq raster line
		sta	$d012 

                

                lda     #$38  // screen ram = 400, bitmap 2000
                sta     $d018 

                lda     #$38  // bitmap mode, screen on, 25 rows (tall) 
                sta     $d011

                lda     #$08  // bitmap singlecolor, 40 cols (wide)
                sta     $d016

		lda	#$01  // background color
                sta     $d021 

		lda	#$00  // border color
                sta     $d020

		rts
interrupt
		; nominal sync code with no sprites:
		sta	int_savea+1	; 10..16
		lda	$dc06		; in the range 1..7
		eor	#7
		sta	*+4
		bpl	*+2
		lda	#$a9
		lda	#$a9
		lda	$eaa5 ; cuento 22 con vice + overhead de 43
                              ; 47+22 = 69 en badline

		; at cycle 35 ?? pero si van menos!
                ; cuento 24 aca con vice...
                ; y en la rasterline #30 como venia.. 47

; effect starts here
                ldx counter    ; 4
                inx            ; 2
                stx counter    ; 4
                cpx #$1       ; 2
                bne postswap   ; 2, por este camino son 14 ciclos, 14+35=49

//                lda #$00
  //              sta esperar
    //            sta esperar+1
esperar:
                lda #$7f
                cmp $d012
                bne esperar

                ldx #$00       ; 2
                stx counter    ; 4

                ; cycle 55

                lda     $d018    ; 4
                and     #$f0     ; 2
                cmp     #$10     ; 2
                bne     poner_18 ; 2
                lda     #$38     ; 2
                sta     $d018    ; 4 // screen ram = c00, bitmap 2000
                
                ; 55 + 16 = 71
                jmp     postswap ; 3
poner_18
                lda     #$18     ; 2
                sta     $d018    ; 4 // screen ram = 400, bitmap 2000


postswap

; effect ends here

		stx	int_savex+1 ; 4
		sty	int_savey+1 ; 4

int_savea	lda	#0          ; 2
int_savex	ldx	#0          ; 2
int_savey	ldy	#0          ; 2 
		lsr	$d019       ; 6
		rti                 ; 6 , deinit = 26 cycles + init (35) = 61 por default


temp .byte 5
counter .byte $ff
started_flag .byte 0

//         * = $6000
//gfx
//         .bin    0,0,"pepe.bin"

//         .bin    0,0,"giphy34.prg"

