		; efo header

		.byt	"EFO2"		; fileformat magic
		.word	0		; prepare routine
		.word	setup		; setup routine
		.word	irq0		; irq handler
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
                tab18   = $9000
                tab11   = $9100
		* = $3000
loadaddr

setup
	sei
	;lda #$35
	;sta $01        ; disable all ROMs
	;lda #$7f
	;sta $dc0d      ; no timer IRQs
	;lda $dc0d      ; clear timer IRQ flags
	lda #$2b
	sta $d011
	lda #$2d
	sta $d012
	lda #$18
	sta $d016
	lda #$09
	sta $d018
	lda #$3d       ; VIC bank $4000-$7FFF (Spindle)
	sta $dd02


   	ldx #0
	stx $d020
    	ldx #0
	stx $d021
	; COPY 8000-3fff to d800-dbff
	ldy #$04
	ldx #$00
	stx $d015      ; disable sprites
ll	lda $8000,x
	sta $d800,x    ; copy color RAM data
	inx
	bne ll
	inc ll+2
	inc ll+5
	dey
	bne ll

	; COPY done
	lda #<nmi
	sta $fffa
	lda #>nmi
	sta $fffb      ; dummy NMI to avoid crashing due to RESTORE

	; x = 0 (init val)
uv8	
	txa
	asl
	asl
	asl
	asl

	; a = x << 4
	and #%01110000       ; video matrixes at $4000 - 5FFF
	ora #8       ; bitmap data at $6000
	sta tab18,x    ; calculate $D018 table ; 8, 18, ... 78. alternate video matrix
	txa
	and #$07
	ora #$38       ; bitmap
	sta tab11,x    ; calculate $D011 table ; 38, 39, ... 3f. modify smooth scroll to y-position
	inx
	bne uv8

	dec $d019      ; clear raster IRQ flag
	cli

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
        nop
        nop
        nop
        nop
        nop


        rts

irq0	
      sei
       ; Jitter correction. Put earliest cycle in parenthesis.
      ; (10 with no sprites, 19 with all sprites, ...)
                ; Length of clockslide can be increased if more jitter
                ; is expected, e.g. due to NMIs.

                dec     0               ; 10..18
                sta     int_savea+1     ; 15..23
                lda     #39-(10)        ; 19..27 <- (earliest cycle)
                sec                     ; 21..29
                sbc     $dc06           ; 23..31, A becomes 0..8
                sta     *+4             ; 27..35
                bpl     *+2             ; 31..39
                lda     #$a9            ; 34
                lda     #$a9            ; 36
                lda     #$a9            ; 38
                lda     $eaa5           ; 40

                ; at cycle 34+(10) = 44

        stx     int_savex+1 ; 48
        sty     int_savey+1 ; 52

;        nop ; 56
        ;nop ; 60
        ;nop ; 62
        ;cmp #$00 ; 65

; loop
;        lda #$00
; esperar
;        cmp $d012
;        bne esperar

        lda #$5   
        sta $d020 
        sta $d021 

        nop
        nop
        nop
        nop

        lda #$0  
        sta $d020 
        sta $d021 


        ; effect goes here
        ; PVM PATCH - PAL-N

        ; Following here is the main FLI loop which forces the VIC-II to read
        ; new color data each rasterline. The loop is exactly 23 clock cycles
        ; long so together with 40 cycles of color DMA this will result in
        ; 63 clock cycles which is exactly the length of a PAL C64 rasterline.
;l0
        ; PVM PATCH - PAL-N
;        nop
;	inx
;	lda tab18,x
;	sta $d018      ; set new color RAM address
;	lda tab11,x
;	sta $d011      ; force new color DMA
;	cpx #199       ; last rasterline?
;	bne l0
;       lda #$30
;        sta $d011      ; open upper/lower border

;         jmp loop


int_savea       lda     #0
int_savex       ldx     #0
int_savey       ldy     #0
                lsr     $d019
;                inc     0

nmi
                cli
                rti

