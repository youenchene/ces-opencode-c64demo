; =============================================================================
; B19_bars_behind_text.asm - B19 Rasterbars behind text
; What you see: three copper bars moving up and down BEHIND a full text screen.
; How:
; - $d021 gets a new colour every raster line, from a 200-entry table
; - the write only has to land in the horizontal border/blank (cycles ~56-62
;   and 0-15), a ~20 cycle window, so no double-IRQ stable raster is needed:
;   the main loop is "jmp *" (IRQ jitter 0..2 cycles)
; - every char row = 1 badline + 7 normal lines: the badline step has only
;   ~20 CPU cycles (VIC steals 40-43), the 7 others are exactly 63 cycles
; - the table is redrawn at the bottom of the frame (3 bars on a sine)
; Docs: docs/08-effects-library.md (B19)
; Based on: codebase64 base:rasterbars_with_screen_on (idea), rewritten
; Limitations: PAL only; no sprites (sprite DMA would steal cycles).
;   Check on real hardware: a write landing outside the window shows as a
;   short colour step at the left or right text edge.
; =============================================================================
!source "c64.asm"

BAR_IRQ = $31                   ; first write happens at the end of line $32
LINES   = 200                   ; 25 rows x 8 lines, from line $33

zp_t    = $20
zp_bar  = $21
zp_n    = $22

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$17                ; ROM font, mixed case
        sta VIC_MEMPTR
        lda #$1b                ; YSCROLL 3: badlines at $33, $3b, ...
        sta VIC_CTRL1
        lda #$20
        +fill_1000 SCREEN
        lda #WHITE
        +fill_1000 COLOR_RAM
        ldx #0                  ; text on every row
-       lda text,x
        !for r, 0, 24 { sta SCREEN + r*40, x }
        txa
        eor #1                  ; shift every other row by 1 char
        tay
        lda text,y
        !for r, 0, 11 { sta SCREEN + (r*2+1)*40, x }
        inx
        cpx #40
        bne -
        jsr make_bars

        +set_irq irq_bars, BAR_IRQ
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *                   ; 3-cycle loop: IRQ jitter 0..2

; -----------------------------------------------------------------------------
; Timing-critical: one page, no branch crosses a page.
; -----------------------------------------------------------------------------
        !align 255, 0
irq_bars:
        +irq_enter              ; handler starts ~cycle 9..11 of line $31, +13
        ldx #0                  ; 2
        lda colors              ; 4
        ldy #18                 ; 2   wait until the end of line $32
-       dey                     ; 18*5-1 = 89
        bne -
        nop                     ; 2
        bit $00                 ; 3   tuned in VICE: the write train is clean
        sta BACKGROUND          ;     from 12 cycles earlier to 7 cycles later
        nop                     ; 2   stands in for cpx/bne (5 cycles)
        bit $00                 ; 3
.row:
        ; -- badline: only ~20 CPU cycles until the next write --------------
        nop                     ; 2
        bit $00                 ; 3
        inx                     ; 2
        lda colors,x            ; 4   (table page-aligned: never +1)
        sta BACKGROUND          ; 4   colour of line 1 of the row
        ; -- 7 normal lines, 63 cycles each --------------------------------
!for i, 1, 7 {
        inx                     ; 2
        lda colors,x            ; 4
        ldy #9                  ; 2
-       dey                     ; 9*5-1 = 44
        bne -
        nop                     ; 2
        nop                     ; 2
        bit $00                 ; 3
        sta BACKGROUND          ; 4  => 63 (the 7th one colours the next badline)
}
        cpx #LINES              ; 2   badline step: 2+3 here + 2+3+2+4+4
        bne .row                ; 3   at .row = 20 CPU cycles
        lda #BLACK
        sta BACKGROUND
        jsr make_bars           ; line ~$fb: plenty of time before line $31
        lda #BAR_IRQ
        sta VIC_RASTER
        +irq_exit

; ---- table: clear, then 3 gradients at sine positions -----------------------
make_bars:
        lda #BLACK
        ldx #LINES-1
-       sta colors,x
        dex
        cpx #$ff
        bne -
        inc zp_t
        ldy #2                  ; bar 2, 1, 0
.bar:   tya                     ; position = sine[t*2 + bar*85]
        sta zp_bar
        asl
        asl
        adc zp_bar              ; *5
        asl
        asl
        asl
        asl                     ; *80
        adc zp_bar
        adc zp_bar
        adc zp_bar
        adc zp_bar
        adc zp_bar              ; *85
        adc zp_t
        adc zp_t
        tax
        lda sine,x              ; 0..LINES-15
        tax
        lda zp_bar              ; gradient offset = bar*16
        asl
        asl
        asl
        asl
        tay
        lda #15
        sta zp_n
-       lda grad,y
        sta colors,x
        inx
        iny
        dec zp_n
        bne -
        ldy zp_bar
        dey
        bpl .bar
        rts

nmi:    rti


text:   !scr "opencode rasterbars behind text  -  pal "
        !scr " "
grad:   !byte 6, 4, 14, 14, 3, 3, 13, 7, 13, 3, 3, 14, 14, 4, 6, 0
        !byte 9, 2, 8, 8, 10, 10, 15, 7, 15, 10, 10, 8, 8, 2, 9, 0
        !byte 11, 5, 5, 13, 13, 7, 7, 1, 7, 7, 13, 13, 5, 5, 11, 0

        !align 255, 0
colors: !fill LINES, 0
        !align 255, 0
sine:   !for i, 0, 255 { !byte int(92.5 + 92 * sin(float(i) * 2 * 3.14159265 / 256)) }
