                ; efo header

                .byt    "EFO2"          ; fileformat magic
                .word   0               ; prepare routine
                .word   setup           ; setup routine
                .word   interrupt       ; irq handler
                .word   0               ; main routine
                .word   0               ; fadeout routine
                .word   0               ; cleanup routine
                .word   0               ; location of playroutine call

                ; tags go here

                ;.byt   "P",$04,$07     ; range of pages in use
                ;.byt   "I",$10,$1f     ; range of pages inherited
                ;.byt   "Z",$02,$03     ; range of zero-page addresses in use
                ;.byt   "X"             ; avoid loading
                ;.byt   "M",<play,>play ; install music playroutine

                .byt    "S"             ; i/o safe
                .byt    0               ; end of tags

                .word   loadaddr

                tab18   = $9000
                tab11   = $9100

                * = $3000
loadaddr

interrupt	
        sta     int_savea+1
        stx     int_savex+1
        sty     int_savey+1

        pha
	;dec $d019
	lda #<irq1
        ldx #>irq1
	sta $fffe      ; set up 2nd IRQ to get a stable IRQ
	stx $ffff
        inc $d012
        asl $d019
        nop
        ; tsx
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
irq1
        ;txs
	nop
        nop

;        ldx #$08                ; +2, 11~12
 ;       dex                     ; +2 * 8, 27~28
  ;      bne *-1                 ; +3 * 7, +2, 50~51
   ;     bit $00                 ; +3, 53~54

;        lda $d012               ; +4, 57~58
;        cmp $d012               ; +4, 61~62
 ;       beq *+2                 ; +2/+3, 64

	lda #$09
	sta $d018      ; setup first color RAM address early
	lda #$38
	sta $d011      ; setup first DMA access early
	pla
	pla
	pla
	dec $d019
	lda #$2d
	sta $d012
	lda #<0
	sta $fffe      ; switch IRQ back to first stabilizer IRQ
	lda $d012
	cmp $d012      ; stabilize last jittering cycle
	beq fj
fj:
	ldx #$0f
ff:	dex
	bne ff

        ; PVM PATCH - PAL-N
        nop
        nop

; 223 

        ; Following here is the main FLI loop which forces the VIC-II to read
        ; new color data each rasterline. The loop is exactly 23 clock cycles
        ; long so together with 40 cycles of color DMA this will result in
        ; 63 clock cycles which is exactly the length of a PAL C64 rasterline.
l0:
        ; PVM PATCH - PAL-N
        nop
	inx
	lda tab18,x
	sta $d018      ; set new color RAM address
	lda tab11,x
	sta $d011      ; force new color DMA
	cpx #199       ; last rasterline?
	bne l0

; 12899

        lda #$30
        sta $d011      ; open upper/lower border
	pla

        lda #<interrupt ; +2, 2
        ldx #>interrupt ; +2, 4
        sta $fffe               ; +4, 8
        stx $ffff               ; +4, 12

        jsr $1200

int_savea       lda     #0
int_savex       ldx     #0
int_savey       ldy     #0

        dec  $d019 
        cli
nmi:
	rti

setup
	;sei
	; lda #$35
	; sta $01        ; disable all ROMs
	; lda #$7f
	; sta $dc0d      ; no timer IRQs
	; lda $dc0d      ; clear timer IRQ flags
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
	; COPY 3c00-3fff to d800-dbff
	ldy #$04
	ldx #$00
	stx $d015      ; disable sprites
ll:	lda $8000,x
	sta $d800,x    ; copy color RAM data
	inx
	bne ll
	inc ll+2
	inc ll+5
	dey
	bne ll
	; COPY done

	lda #<interrupt
	sta $fffe
	lda #>interrupt
	sta $ffff
	lda #<nmi
	sta $fffa
	lda #>nmi
	sta $fffb      ; dummy NMI to avoid crashing due to RESTORE
	lda #$01
	sta $d01a      ; enable raster IRQs

	; x = 0 (init val)
uv8:	
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

;	dec $d019      ; clear raster IRQ flag
;	cli
        rts
	;jmp *          ; that's it, no more action needed

