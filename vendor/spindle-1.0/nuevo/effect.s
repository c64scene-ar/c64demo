		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	prepare		; prepare routine
		.word	setup		; setup routine
		.word	0	; irq handler
		.word	main		; main routine
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

		* = $6000
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
                lda     #$00    // was 0x02
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
                lda     #$00 // was 0x02
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
                lda     #$38  // screen ram = 400, bitmap 2000
                sta     $d018 

                lda     #$38  // bitmap mode, screen on, 25 rows (tall) 
                sta     $d011

                lda     #$08  // bitmap singlecolor, 40 cols (wide)
                sta     $d016

		lda	#$00  // background color
                sta     $d021 

		lda	#$00  // border color
                sta     $d020

		rts
main
jsr prepare
.bin 0,0,"fx.bin"
; effect ends here
		rts                 ; 6 , deinit = 26 cycles + init (35) = 61 por default


counter .byte 00
counter2 .byte 00
//         * = $6000
//gfx
//         .bin    0,0,"pepe.bin"

//         .bin    0,0,"giphy34.prg"

