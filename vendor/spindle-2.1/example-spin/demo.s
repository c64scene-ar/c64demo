
	.word	entry
	* = $200
entry
	; Call music init.

	lda	#0
	jsr	$1000

	; Set up raster interrupt.

	lda	#$3b
	sta	$d011
	lda	#$ff
	sta	$d012
	lda	#$01
	sta	$d01a
	lsr	$d019

	; Install simple IRQ wrapper to call playroutine.
	; Alternatively, we could use the $fffe vector normally.

	ldx	#<$1003
	ldy	#>$1003
	jsr	$c10

	; Switch banks so we can watch the loading process.

	lda	#$3d
	sta	$dd02
	lda	#$08
	sta	$d018
	lda	#$18
	sta	$d016
	lda	#$1
	sta	$d020

	; Load the first picture.

	jsr	$c90

        ;jmp disablebot
	; Wait for space, then load the next picture, etc.

	jsr	wait4space
	jsr	$c90
	jsr	wait4space
	jsr	$c90

	; All done. The drive has been reset as part of the final loader call.

	jmp	*

  
disablebot:

;l1:
;  bit $d011
;  bpl l1
;l2:
;  bit $d011
;  bmi l2
;  lda #$1b
;  sta $d011
;  lda #$00
;  sta $3fff

wait_f9:
  ;sei
  lda #$fa
wait_f9_loop:
  cmp $d012
  bne wait_f9_loop

  lda $d011
  and #$f7
  sta $d011

wait_ff:
  lda #$ff
wait_ff_loop:
  cmp $d012
  bne wait_ff_loop

  lda $d011
  ora #$08
  sta $d011

  jmp wait_f9 
   

wait4space:
	lda	#$ff
	sta	$dc02
	lsr
	sta	$dc00
	lda	#$10
	bit	$dc01
	beq	*-3
	bit	$dc01
	bne	*-3
	rts

