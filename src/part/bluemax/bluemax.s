#include "header.i"


; Mem map 
; $3800 -- charset


setup
    lda  #$22   ; set first irq
    sta  $d012  ; at rasterline $22

    ; background color 
    lda #$00
    sta $d021   ; background
    sta $d020   ; border

    ; clear screen

    tax 
    lda #$20 ; space char
    clr_scr:
      sta $0400, x
      sta $0500, x
      sta $0600, x
      sta $0700, x
      dex
      bne clr_scr


loop_text  
           lda line1,x      ; read characters from line1 table of text...
           sta $0428,x      ; ...and store in screen ram near the center
           lda line2,x      ; read characters from line1 table of text...
           sta $0478,x      ; ...and put 2 rows below line1
           lda line3,x      ; read characters from line1 table of text...
           sta $0770,x      ; ...and put 2 rows below line1
           
           lda color_table,x
           sta $d800,x 
           sta $d828,x 
           sta $d878,x 
           sta $db70,x 
           inx 
           cpx #$28         ; finished when all 40 cols of a line are processed
           bne loop_text




;============================================================
; set character set pointer to our custom set, turn off 
; multicolor for characters, then output three lines of text
;============================================================

    ; setup charset
    lda $d018
    ora #$0e       ; set chars location to $3800 for displaying the custom font
    sta $d018      ; Bits 1-3 ($400+512bytes * low nibble value) of $d018 sets char location
                  ; $400 + $200*$0E = $3800
    lda $d016      ; turn off multicolor for characters
    and #$ef       ; by cleaing Bit#4 of $D016
    sta $d016


    rts

; =============================================================================
; I R Q S 
; =============================================================================


interrupt
    // nominal sync code with no sprites:
    sta  int_savea+1  // 10..16
    lda  $dc06        // in the range 1..7
    eor  #7
    sta  *+4
    bpl  *+2
    lda  #$a9
    lda  #$a9
    lda  $eaa5

    // at cycle 35

    stx  int_savex+1
    sty  int_savey+1

    // effect goes here
	  

catch_raster_line:
	  lda $d012  ; read current raster line
	  cmp #$22   
	  beq cmp_22
	  cmp #$32
	  beq cmp_32
 	  cmp #$42
	  beq cmp_42

    jmp done_irqs

cmp_22:
         
    lda $d011
    and #%01111111
    sta $d011
 
    lda  #$32
    sta  $d012
	  
	  jsr rasterbar

cmp_32:
          
    lda $d011
    and #%01111111
    sta $d011
 

	  lda  #$42
    sta  $d012

    lda #$00  ; black 
    sta $d020 ; screen

	  jmp done_irqs

cmp_42:
          
    lda $d011
    and #%01111111
    sta $d011
 
    lda  #$22
    sta  $d012

    lda #$00  ; black 
    sta $d020 ; screen

    // in last raster, change all interrupts calls

	  jmp done_irqs
          

  

done_irqs:

int_savea  lda  #0
int_savex  ldx  #0
int_savey  ldy  #0
  lsr  $d019
  rti

; =============================================================================
; M I S C  -  C O D E 
; =============================================================================

rasterbar:
  ldx #$00
  raster_loop:
    lda sine, x
    sta $d020

    cpx #51 ; 51 decimal per line
    beq rasterbar ; finish line? then start again
    inx
    bne raster_loop
return_rasterbar:    
    rts


rand_color_map
          ; rnd routine
          ;pha
          ;lda seed
          ;beq doEor
          ;asl
          ;beq noEor ;if the input was $80, skip the EOR
          ;bcc noEor
          ;doEor: 
          ;  eor #$1d
          ;noEor:  
          ;  sta seed           
          ;sta $d800
          ;php
          

          //DBE7


; =============================================================================
; D A T A 
; =============================================================================
seed .byt $20
line1 .asc "1234567890123456789012345678901234567890"
line2 .asc "1234567890123456789012345678901234567890"
line3 .asc "1234567890123456789012345678901234567890"


raster_block_offset:
.byt $00

color_table:
.byt $01, $02, $03, $04
.byt $05, $06, $07, $08
.byt $09, $0a, $0b, $0c
.byt $0d, $0e, $0f, $01



sine:
.bin 0,0,"sine.bin"
      
scroll:

    ldx delay
    dex
    bne continue_scroll

    lda offset

    adc #$01
    and #$07
    sta offset

    lda $d016
    and 248
    adc offset
    sta $d016

    ldx #$02

continue_scroll:

    stx delay
    asl $d019
    rts

background_color:
.byt $01
offset:
.byt $00
delay 
.byt $02    
