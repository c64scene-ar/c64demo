(*
Copyright (c) 2007, Johan Kotlinski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*)

(* Note: FLI viewer code is written by Graham! *)

let basic_header = "
!macro basic_header {
	!byte $b, $08, $EF, $00, $9E, $32, $30, $36,$31, $00, $00, $00 
}

!to \"__FILE__.prg\", cbm    ; set output file and format
	*= $0801		; Start at C64 BASIC start
	+basic_header		; Call program header macro
    ";;

let multicolor_viewer = basic_header ^ "

	lda	$d0
	lda     $D016 ;enable multicolor
	ora     #$10
	sta     $D016

	lda     #$BB ;enable bitmap mode
	sta     $D011

	lda     #$16 ;vic base = $4000
	sta     $DD00

	lda     #$08 ; video matrix = 4000, bitmap base = 6000
	sta     $D018

    lda     #__BORDERCOLOR__
	sta     $D020
	lda     #__BGCOLOR__
	sta     $D021
;
; memcpy((void*)0xd800, (void*)0x2000, 0x400);
;
	ldx	#0
.memcpy
	lda	$2000, x
	sta	$d800, x
	lda	$2100, x
	sta	$d900, x
	lda	$2200, x
	sta	$da00, x
	lda	$2300, x
	sta	$db00, x
	dex
	bne	.memcpy

.loop
	jmp	.loop

*= $4000
!bin \"__FILE__-v.bin\"

*= $6000
!bin \"__FILE__.bin\"

*= $2000
!bin \"__FILE__-c.bin\"
";;

let hires_sprite_viewer = basic_header ^ "

NORMAL = 0
NOSPRITES = 1
ONLYSPRITES = 2

MODE = NORMAL
;MODE = ONLYSPRITES
;MODE = NOSPRITES

!if MODE = ONLYSPRITES {
    lda #$1b
    sta $d011

.clean
    lda #0
.msb
    sta $5000
    inc .msb + 1
    bne .clean
    inc .msb + 2
    lda .msb + 2
    cmp #$80
    bne .clean
} else {
	lda #$3b ;enable bitmap mode
	sta	$d011
}

	lda	#$16 ;vic base address = $4000
	sta	$dd00

	lda #$48 ;video matrix = 5000, bitmap base = 6000
	sta	$d018

	lda	#__BORDERCOLOR__
	sta	$d020
	sta	$d021

!if MODE != NOSPRITES {
	lda	#$ff ;enable sprites
	sta	$d015
}

_multiplexer:
	lda #$7f
	sta $dc0d ;cia 1 off
	sta $dd0d ;cia 2 off

	sei
	lda #<swap_start
	sta $0314
	lda #>swap_start
	sta $0315

	lda #$f1
	sta $d01a

	lda $dc0d
	lda $dd0d
	asl $d019

	cli
.loop
	jmp	.loop

return
	;clear interrupt register
	lda	#1
	sta	$d019

    pla
	tay
	pla
	tax
	pla
	rti

sprite_ptrs = $53f8
swap_start
!src \"__FILE__-swap.a\"

*= $6000
!binary \"__FILE__.bin\"

*= $5000
!binary \"__FILE__-v.bin\"

*= $4000
!binary \"__FILE__-sprites.bin\"
";;

let hires_viewer = basic_header ^ "

	lda #$3b ;enable bitmap mode
	sta	$d011

	lda	#$16 ;vic base address = $4000
	sta	$dd00

	lda #$48 ;video matrix = 5000, bitmap base = 6000
	sta	$d018

	lda	#__BORDERCOLOR__
	sta	$d020
	sta	$d021

.loop
	jmp	.loop

*= $6000
!binary \"__FILE__.bin\"

*= $5000
!binary \"__FILE__-v.bin\"
";;

let fli_viewer = basic_header ^ "

jmp	start

tab18   = $0e00
tab11   = $0f00

	*= $1000

irq0:	pha
	dec $d019
	inc $d012
	lda #<irq1
	sta $fffe      ; set up 2nd IRQ to get a stable IRQ
	cli

        ; Following here: A bunch of NOPs which allow the 2nd IRQ
        ; to be triggered with either 0 or 1 clock cycle delay
        ; resulting in an \"almost\" stable IRQ.

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
irq1:
	nop
	nop
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
	lda #<irq0
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
        lda #$30
        sta $d011      ; open upper/lower border
	pla
nmi:
	rti

start:
	sei
	lda #$35
	sta $01        ; disable all ROMs
	lda #$7f
	sta $dc0d      ; no timer IRQs
	lda $dc0d      ; clear timer IRQ flags
	lda #$2b
	sta $d011
	lda #$2d
	sta $d012
	lda #$18
	sta $d016
	lda #$09
	sta $d018
	lda #$96       ; VIC bank $4000-$7FFF
	sta $dd00

    ldx #__BORDERCOLOR__
	stx $d020
    ldx #__BGCOLOR__
	stx $d021
	; COPY 3c00-3fff to d800-dbff
	ldy #$04
	ldx #$00
	stx $d015      ; disable sprites
ll:	lda $3c00,x
	sta $d800,x    ; copy color RAM data
	inx
	bne ll
	inc ll+2
	inc ll+5
	dey
	bne ll
	; COPY done

	lda #<irq0
	sta $fffe
	lda #>irq0
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

	dec $d019      ; clear raster IRQ flag
	cli
	jmp *          ; that's it, no more action needed

; link a demo picture
*= $3c00
!binary \"__FILE__-c.bin\"

*= $4000
!binary \"__FILE__-v.bin\"

*= $6000
!binary \"__FILE__.bin\"
";;

let mci_viewer = basic_header ^ "

	lda #$7f
	sta $dc0d      ; no timer IRQs
	lda $dc0d      ; clear timer IRQ flags

	lda	$d0
	lda     $D016 ;enable multicolor
	ora     #$10
	sta     $D016

	lda     #$BB ;enable bitmap mode
	sta     $D011

	lda     #$08 ; video matrix = 8000, bitmap base = a000
	sta     $D018

    lda     #__BORDERCOLOR__
	sta     $d020
	lda     #__BGCOLOR__
	sta     $d021

    lda #$ff
    sta $d015 ;enable all
    sta $d017 ;expand y

!for .sprite, 8 {
    lda #1 ;x
    sta $d000 + (.sprite - 1) * 2

    lda #(.sprite - 1) * 42 AND $ff ;y
    sta $d001 + (.sprite - 1) * 2

    lda # __BORDERCOLOR__
    sta $d027 + (.sprite - 1)

    lda #$10
    sta $43f7 + .sprite
    sta $83f7 + .sprite
}

	ldx	#0
.memcpy
	lda	$2000, x
	sta	$d800, x
	lda	$2100, x
	sta	$d900, x
	lda	$2200, x
	sta	$da00, x
	lda	$2300, x
	sta	$db00, x
	dex
	bne	.memcpy

.loop
    lda $d012
    cmp #$ff
    bne .loop

	lda     #$16 ;vic base = $4000
	sta     $DD00

	lda     $D016 ;x scroll = 0
    and #%11111000
	sta     $D016

.loop2
    lda $d012
    cmp #$ff
    bne .loop2

	lda     #$15 ;vic base = $8000
	sta     $DD00

	lda     $D016 ;x scroll = 1
    and #%11111000
    ora #1
	sta     $D016

    jmp .loop

*= $4000
!bin \"__FILE__1-v.bin\"

*= $6000
!bin \"__FILE__1.bin\"

*= $8000
!bin \"__FILE__2-v.bin\"

*= $a000
!bin \"__FILE__2.bin\"

*= $2000
!bin \"__FILE__-c.bin\"

!macro SpriteLine .v {
    !by .v>>16, (.v>>8)&255, .v&255
}

*= $4400

+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################

*= $8400

+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
+SpriteLine %########################
";;

let asslace_viewer = basic_header ^ "

	lda #$7f
	sta $dc0d      ; no timer IRQs
	lda $dc0d      ; clear timer IRQ flags

	lda	$d0
	lda     $D016 ;enable multicolor
	ora     #$10
	sta     $D016

	lda     #$BB ;enable bitmap mode
	sta     $D011

	lda     #$08 ; video matrix = 8000, bitmap base = a000
	sta     $D018

    lda     #__BORDERCOLOR__
	sta     $d020
    lda     #__BGCOLOR__
	sta     $d021

    ; ---------------- setup sprites - start

    lda #$ff
    sta $d015 ;enable all
    sta $d01d ;2x horiz

    lda #%01000000
    sta $d010 ;xpos msb
    
    ;sprite ptrs
    ldx #$7 
.ptrloop
    lda #$10
    sta $43f8, x
    sta $83f8, x
    lda #0
    sta $d027, x
    dex
    bpl .ptrloop

    ; ---------------- setup sprites - end

	ldx	#0
.memcpy
	lda	$2000, x
	sta	$d800, x
	lda	$2100, x
	sta	$d900, x
	lda	$2200, x
	sta	$da00, x
	lda	$2300, x
	sta	$db00, x
	dex
	bne	.memcpy

.loop
    lda $d012
    cmp #$2a
    bne .loop

    lda     #$16 ;vic base = $4000
    sta     $DD00

    jsr spriteswap

.loop2
    lda $d012
    cmp #$2a
    bne .loop2

    lda     #$15 ;vic base = $8000
    sta     $DD00

    jsr spriteswap

    jmp .loop


!macro do_swap .line, .xmod {
.xoffset = -1 - .xmod * 2

!for sprite, 7 {
-
!set .ypos = .line + 3 * (sprite - 1) AND $ff
!if (.ypos % 8 != 3 OR .ypos < $33) AND .ypos < $fb {
    lda $d012
    cmp #.ypos
    bne -

!if .ypos < $40 {
    nop
}
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

    sta $d001 + (sprite-1) * 2

    lda #($18 + .xoffset + (46 * (sprite-1))) AND $ff ;xpos lsb
    sta $d000 + (sprite-1) * 2
} else {
    ;fixup with sprite 7
    lda #.ypos
    sta $d00f

    lda #($18 + .xoffset + (46 * (sprite-1))) AND $ff ;xpos lsb
    sta $d00e

    ;xpos msb
!if ($18 + .xoffset + (46 * (sprite-1))) AND $100 {
    lda #%11000000
} else {
    lda #%01000000
}
    sta $d010
} ;end of emergency fixup
} ;end of for sprite

} ;end of do_swap

*= $1000
spriteswap

.base = $33 - 21
+do_swap (.base-1), 0
+do_swap (.base-1+21), 1
+do_swap (.base-1+21*2), 0
+do_swap (.base-1+21*3), 1
+do_swap (.base-1+21*4), 0
+do_swap (.base-1+21*5), 1
+do_swap (.base-1+21*6), 0
+do_swap (.base-1+21*7), 1
+do_swap (.base-1+21*8), 0
+do_swap (.base-1+21*9), 1
+do_swap (.base-1+21*10), 0

    rts

!macro SpriteLine .v {
    !by .v>>16, (.v>>8)&255, .v&255
}

*= $4000
!bin \"__FILE__1-v.bin\"

*= $4400

+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
!byte 0 ; pad to 64-byte block

*= $6000
!bin \"__FILE__1.bin\"

*= $8000
!bin \"__FILE__2-v.bin\"

*= $8400

+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
+SpriteLine %.#.#.#.#.#.#.#.#.#.#.#.#
+SpriteLine %#.#.#.#.#.#.#.#.#.#.#.#.
!byte 0 ; pad to 64-byte block

*= $a000
!bin \"__FILE__2.bin\"

*= $2000
!bin \"__FILE__-c.bin\"
";;

let ifli_viewer = basic_header ^ "

jmp	start

tab18   = $0e00
tab11   = $0f00

	*= $1000

irq0:	pha
	dec $d019
	inc $d012
	lda #<irq1
	sta $fffe      ; set up 2nd IRQ to get a stable IRQ
	cli

        ; Following here: A bunch of NOPs which allow the 2nd IRQ
        ; to be triggered with either 0 or 1 clock cycle delay
        ; resulting in an \"almost\" stable IRQ.

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
irq1:
	nop
	nop
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
	lda #<irq0
	sta $fffe      ; switch IRQ back to first stabilizer IRQ
	lda $d012
	cmp $d012      ; stabilize last jittering cycle
	beq fj
fj:
	ldx #$0f
ff:	dex
	bne ff


        ; Following here is the main FLI loop which forces the VIC-II to read
        ; new color data each rasterline. The loop is exactly 23 clock cycles
        ; long so together with 40 cycles of color DMA this will result in
        ; 63 clock cycles which is exactly the length of a PAL C64 rasterline.
l0:
	inx
	lda tab18,x
	sta $d018      ; set new color RAM address
	lda tab11,x
	sta $d011      ; force new color DMA
	cpx #199       ; last rasterline?
	bne l0

    lda #$30
    sta $d011      ; open upper/lower border

	pla

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

    ;flip between vic banks
    lda $dd00
    eor #3
    sta $dd00

    ;smooth scroll x
    lda $d016
    eor #1
    sta $d016

nmi:
	rti

start:
	sei
	lda #$35
	sta $01        ; disable all ROMs
	lda #$7f
	sta $dc0d      ; no timer IRQs
	lda $dc0d      ; clear timer IRQ flags
	lda #$2b
	sta $d011
	lda #$2d
	sta $d012
	lda #$18 + 1
	sta $d016
	lda #$09
	sta $d018
    lda #$95; $96       ; VIC bank $4000-$7FFF
	sta $dd00

    ldx #__BORDERCOLOR__
	stx $d020
    ldx #__BGCOLOR__
	stx $d021
	; COPY 3c00-3fff to d800-dbff
	ldy #$04
	ldx #$00
	stx $d015      ; disable sprites
ll:	lda $3c00,x
	sta $d800,x    ; copy color RAM data
	inx
	bne ll
	inc ll+2
	inc ll+5
	dey
	bne ll
	; COPY done

	lda #<irq0
	sta $fffe
	lda #>irq0
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

	dec $d019      ; clear raster IRQ flag
	cli
	jmp *          ; that's it, no more action needed

; link a demo picture
*= $3c00
!binary \"__FILE__1-c.bin\"

*= $4000
!binary \"__FILE__1-v.bin\"

*= $6000
!binary \"__FILE__1.bin\"

*= $8000
!binary \"__FILE__2-v.bin\"

*= $a000
!binary \"__FILE__2.bin\"
";;

