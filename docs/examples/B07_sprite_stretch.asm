; =============================================================================
; B07_sprite_stretch.asm - B7 Sprite stretching
; What you see: the word "OPEN" in 4 wide sprites, each of its 21 lines
;   stretched 1-5 raster lines, the stretch rolling down like a wave.
; How:
; - the Y-expand flip-flop decides at cycle ~16 of each line whether the
;   sprite moves to its next data line. Writing $d017 = 0 sets the
;   flip-flop; with $d017 = $ff it is inverted at cycle 55
; - every line (in cycles ~17-54): $d017 = 0, then $d017 = tab[line]:
;   $ff -> flip-flop ends cleared -> the same data line is shown again,
;   $00 -> flip-flop stays set -> next data line
; - the window is ~38 cycles wide, so a polling loop is enough (no stable
;   raster), but badlines would steal it: the loop also writes $d011
;   YSCROLL = (line+2) & 7 every line (FLD) so no badline happens there
; - tab[] is rebuilt each frame: row k lasts 1 + sine[t*3 + k*12] lines
; Docs: docs/08-effects-library.md (B7)
; Based on: codebase64 base:stretching_sprites, rewritten
; Limitations: the text screen below the stretch area is pushed down by the
;   FLD (left empty here). Cycle timing tuned for 4 sprites; check on real
;   hardware.
; =============================================================================
!source "c64.asm"

SPRITES    = $2000              ; 4 shapes, pointers $80-$83
LOOP_START = $50                ; first line of the per-line loop
SPR_Y      = $56
LINES      = 150                ; lines handled by the loop ($50-$e5)
ROWS_SKIP  = SPR_Y - LOOP_START ; table entries before the sprite starts

zp_t    = $20
zp_k    = $21
zp_src  = $22                   ; 2 bytes
zp_dst  = $24                   ; 2 bytes
zp_b    = $26
o0      = $27                   ; 3 bytes: one 24-pixel sprite row
o1      = $28
o2      = $29
zp_s    = $2a
zp_flag = $2b

        +basic_upstart

start:
        +demo_init nmi
        jsr make_shapes         ; reads the char ROM: IRQs must be off
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        sta $3fff               ; idle graphics during the FLD: empty
        lda #$20
        +fill_1000 SCREEN
        lda #GREY
        +fill_1000 COLOR_RAM
        ldx #39
-       lda title,x
        sta SCREEN+1*40,x
        dex
        bpl -
        lda #$17
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        ldx #3
-       txa
        ora #SPRITES/64
        sta SCREEN+$3f8,x
        lda spr_col,x
        sta SPR0_COLOR,x
        txa
        asl
        tay
        lda spr_x,x
        sta SPR0_X,y
        lda #SPR_Y
        sta SPR0_Y,y
        dex
        bpl -
        lda #$0f
        sta SPR_EXPAND_X
        sta SPR_ENABLE
        jsr build_tab
        +set_irq irq_stretch, LOOP_START-2
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda zp_flag             ; rebuild the table after each stretch loop
        beq main
        lda #0
        sta zp_flag
        jsr build_tab
        jmp main

; ---- per-line loop: Y-expand flip-flop + FLD, ~LINES lines -----------------
        !align 255, 0
irq_stretch:
        +irq_enter
        ldy #0
        ldx #LOOP_START
.line:
-       cpx VIC_RASTER          ; wait for line X (seen at cycle ~3-10,
        bne -                   ; after the sprite DMA)
        nop                     ; 10 cycles: get past cycle 16
        nop
        nop
        nop
        nop
        lda #0                  ; 2
        sta SPR_EXPAND_Y        ; 4  flip-flop set   (cycle ~19-26)
        lda tab,y               ; 4
        sta SPR_EXPAND_Y        ; 4  $ff = repeat, $00 = next line
        lda fld,y               ; 4
        sta VIC_CTRL1           ; 4  YSCROLL = (line+2)&7: no badline
        inx                     ; 2
        iny                     ; 2
        cpy #LINES              ; 2
        bne .line               ; 3  ~45 cycles + 4 sprites DMA < 63
        lda #0
        sta SPR_EXPAND_Y
        lda #$1b
        sta VIC_CTRL1
        inc zp_flag
        +set_irq irq_stretch, LOOP_START-2
        +irq_exit

; ---- tab: ROWS_SKIP x $00, then per sprite row k: (n-1) x $ff + $00 --------
build_tab:
        inc zp_t
        ldy #0
        lda #0
-       sta tab,y
        iny
        cpy #ROWS_SKIP
        bne -
        lda #0
        sta zp_k
.row:   lda zp_k                ; n = 1 + wave[t*3 + k*12]
        asl
        asl
        adc zp_k                ; k*5 (k < 21: no carry)
        asl
        adc zp_k                ; k*11
        adc zp_k                ; k*12
        adc zp_t
        adc zp_t
        adc zp_t
        tax
        lda wave,x
        tax                     ; X = n - 1 repeats
        beq +
        lda #$ff
-       sta tab,y
        iny
        dex
        bne -
+       lda #0
        sta tab,y
        iny
        inc zp_k
        lda zp_k
        cmp #21
        bne .row
        lda #0                  ; rest of the table: plain lines
-       sta tab,y
        iny
        cpy #LINES
        bcc -
        rts

; ---- "OPEN" from the char ROM: 3x wide, 8 font rows -> 21 sprite rows -------
make_shapes:
        lda #$33
        sta CPU_PORT
        ldx #3
.spr:   stx zp_s
        lda letters,x
        asl
        asl
        asl
        sta zp_src
        lda #$d0
        adc #0
        sta zp_src+1
        lda spr_lo,x
        sta zp_dst
        lda #>SPRITES
        sta zp_dst+1
        lda #0
        sta zp_k
.r:     ldy zp_k
        ldx font_row,y          ; sprite row k shows font row k*8/21
        txa
        tay
        lda (zp_src),y
        sta zp_b
        ldx #8
-       asl zp_b                ; each font bit -> 3 sprite bits
        php
        rol o2
        rol o1
        rol o0
        plp
        php
        rol o2
        rol o1
        rol o0
        plp
        rol o2
        rol o1
        rol o0
        dex
        bne -
        ldy zp_k
        lda row3,y
        tay
        lda o0
        sta (zp_dst),y
        iny
        lda o1
        sta (zp_dst),y
        iny
        lda o2
        sta (zp_dst),y
        inc zp_k
        lda zp_k
        cmp #21
        bne .r
        ldx zp_s
        dex
        bpl .spr
        lda #BANK_IO_ONLY
        sta CPU_PORT
        rts

nmi:    rti

letters:  !scr "open"            ; screen codes < 64 (ROM upper set)
spr_lo:   !byte 0, 64, 128, 192
spr_x:    !for i, 0, 3 { !byte 88 + i*48 }
spr_col:  !byte 7, 13, 3, 14
font_row: !for k, 0, 20 { !byte k*8/21 }
row3:     !for k, 0, 20 { !byte k*3 }
fld:      !for j, 0, LINES-1 { !byte $18 + ((LOOP_START + j + 2) & 7) }
title:    !scr "         B7: sprite stretching          "

        !align 255, 0
wave:     !for i, 0, 255 { !byte int(2.5 + 2.49 * sin(float(i) * 2 * 3.14159265 / 256)) }
tab:      !fill 256, 0          ; one byte per loop line
