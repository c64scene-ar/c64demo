		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	0		; prepare routine
		.word	setup		; setup routine
		.word	0		; irq handler
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
		* = $2000
loadaddr

setup

                ; lda     #$35
                ; sta     1

		lda	#$3e 
		sta	$dd02
		lda	#0
		sta	$d015
		sta	$d017
		sta	$d01b
		sta	$d01c
		sta	$d01d
		lda	#$30
		sta	$d012


              	lda #$3b ;enable bitmap mode
             	sta	$d011

   ; PVM patch
        ; hires singlecolor.. w00t?
        lda     $d016
        and     %11101111
        sta     $d016


                lda     $d018
                and     #%00001111
                ora     #%00101000 ; video matrix = 8800, bitmap base a000
                sta     $d018

              ;	lda #$48 ;video matrix = 9000, bitmap base = a000
         ;	sta	$d018

          	lda	#0
            	sta	$d020
               	sta	$d021

		rts

