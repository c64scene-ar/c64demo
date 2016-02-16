;------------------------
swap_banks
        ldy swap_addr+2 
        ldx swap_addr+0 
        stx swap_addr+2 
        sty swap_addr+0 
        ldy swap_addr+3
        ldx swap_addr+1
        stx swap_addr+3
        sty swap_addr+1
        jmp swap_cmp_and_swap
swap_bank_registers
        ldy swap_addr+3
swap_cmp_and_swap
        cpy #$3c        ; WARNING hardcoded, depends on using $3cxx for one bank
        bne swap_to_two
swap_to_one
        ;
        ; Screen configuration
        ;
        ; http://codebase64.org/doku.php?id=base:vicii_memory_organizing
        ;
        ; Active frame buffer at $3800, display at $3c00
        ;
        lda     #%00001111 ; Char ROM + Unused bit, leave them alone 
        and     $d018
        ora     #%11100000 ; $D018 = %1110xxxx -> screenmem is at $3800 
        sta     $d018
        jmp swap_finish
swap_to_two
        ;
        ; Active frame buffer at $3c00, display at $3800
        ;
        lda     #%00001111 ; Char ROM + Unused bit, leave them alone 
        and     $d018

        ora     #%11110000 ; $D018 = %1111xxxx -> screenmem is at $3c00 
        sta     $d018
swap_finish
        rts

; copy current screen to swap
;copy_to_swap
        ; the second element is the currently selected bank
;        ldx swap_addr+2
;        stx sc_s+1
;        ldx swap_addr+3
;        stx sc_s+2

        ; the first one is the frame buffer
;        ldx swap_addr+0
;        stx sc_d+1
;        ldx swap_addr+1
;        stx sc_d+2
;        jsr screen_copy
;        rts


copy_to_swap_stage_1
        ; the second element is the currently selected bank
        ldx swap_addr+2
        stx sc_s+1
        ldx swap_addr+3
        stx sc_s+2

        ; the first one is the frame buffer
        ldx swap_addr+0
        stx sc_d+1
        ldx swap_addr+1
        stx sc_d+2
        jsr screen_copy

         ; the second element is the currently selected bank
        clc
        lda swap_addr+2
        adc #$fa
        sta sc_s+1
        lda swap_addr+3
        adc #$00
        sta sc_s+2

        ; the first one is the frame buffer
        clc
        lda swap_addr+0
        adc #$fa
        sta sc_d+1
        lda swap_addr+1
        adc #$00
        sta sc_d+2
        jsr screen_copy
        rts

copy_to_swap_stage_2
         ; the second element is the currently selected bank
        clc
        lda swap_addr+2
        adc #$f4
        sta sc_s+1
        lda swap_addr+3
        adc #$01
        sta sc_s+2

        ; the first one is the frame buffer
        clc
        lda swap_addr+0
        adc #$f4
        sta sc_d+1
        lda swap_addr+1
        adc #$01
        sta sc_d+2
        jsr screen_copy

         ; the second element is the currently selected bank
        clc
        lda swap_addr+2
        adc #$ee
        sta sc_s+1
        lda swap_addr+3
        adc #$02
        sta sc_s+2

        ; the first one is the frame buffer
        clc
        lda swap_addr+0
        adc #$ee
        sta sc_d+1
        lda swap_addr+1
        adc #$02
        sta sc_d+2
        jsr screen_copy

         ; the second element is the currently selected bank
;        clc
;        lda swap_addr+2
;        adc #$20
;        sta sc_s+1
;        lda swap_addr+3
;        adc #$03
;        sta sc_s+2;

        ; the first one is the frame buffer
;        clc
;        lda swap_addr+0
;        adc #$20
;        sta sc_d+1
;        lda swap_addr+1
;        adc #$03
;        sta sc_d+2
;        jsr screen_copy
        rts


swap_addr .word $3c00, $3800
