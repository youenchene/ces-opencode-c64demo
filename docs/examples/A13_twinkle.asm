; =============================================================================
; A13_twinkle.asm - A13 Twinkling windows / stars
; What you see: a night skyline whose windows switch on and off at random,
; under a sky of twinkling stars.
; Technique:
; - the screen never changes, only colour RAM: each window is a solid block
;   ($a0) whose colour goes YELLOW (lit) or BLACK (dark)
; - at start-up, the colour RAM address of every window cell goes in a table
;   (win_lo/win_hi). Each frame: one random window lit, another one darkened
; - stars: 64 '.' cells (positions made at assemble time); each frame one random
;   star turns WHITE and another one goes back to GREY
; - random numbers: 16-bit Galois LFSR (period 65535)
; Docs: docs/08-effects-library.md (A13)
; =============================================================================
!source "c64.asm"

SKY_ROWS  = 13                  ; stars in rows 0-12
STARS     = 64

zp_ptr     = $20                ; 2 bytes
zp_col     = $22                ; 2 bytes
rnd        = $24                ; 2 bytes
frame_flag = $26
nwin       = $27                ; number of windows found (max 255)
xcol       = $28
yrow       = $29

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        lda #BLUE
        sta BACKGROUND
        lda #$17
        sta VIC_MEMPTR
        lda #$20
        +fill_1000 SCREEN
        lda #GREY
        +fill_1000 COLOR_RAM
        jsr draw_stars
        jsr draw_skyline
        lda #1
        sta rnd
        lda #0
        sta rnd+1

        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_frame, $fc
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag
        beq main
        lda #0
        sta frame_flag
        jsr twinkle
        jmp main

irq_frame:
        +irq_enter
        inc frame_flag
        +irq_exit

; ---- per frame: 2 windows, 2 stars -----------------------------------------
twinkle:
        jsr random_window
        lda #YELLOW
        sta (zp_ptr),y
        jsr random_window
        lda #BLACK
        sta (zp_ptr),y
        jsr random
        and #STARS-1
        tax
        lda #WHITE
        jsr .star
        jsr random
        and #STARS-1
        tax
        lda #GREY
.star:  ldy star_hi,x
        sty zp_ptr+1
        ldy star_lo,x
        sty zp_ptr
        ldy #0
        sta (zp_ptr),y
        rts

; zp_ptr = colour RAM of a random window, Y = 0
random_window:
-       jsr random
        cmp nwin
        bcs -                   ; retry until index < nwin
        tax
        lda win_lo,x
        sta zp_ptr
        lda win_hi,x
        sta zp_ptr+1
        ldy #0
        rts

; 16-bit Galois LFSR (taps $b400, period 65535), returns the low byte.
; (An 8-bit LFSR is too short: with a fixed number of calls per frame the
; pattern repeats every ~64 frames and the picture freezes.)
random: lsr rnd+1
        ror rnd
        bcc +
        lda rnd+1
        eor #$b4
        sta rnd+1
+       lda rnd
        rts

; ---- static scene ----------------------------------------------------------
draw_stars:
        ldx #STARS-1
-       lda star_lo,x
        sta zp_ptr
        lda star_hi,x
        sec
        sbc #>(COLOR_RAM-SCREEN)
        sta zp_ptr+1
        ldy #0
        lda #'.'
        sta (zp_ptr),y
        dex
        bpl -
        rts

; one building per column group: column x is filled from row 24-height[x]
; to row 24. Cells at odd column and odd row (below the roof) are windows.
draw_skyline:
        lda #0
        sta nwin
        sta xcol
.col:   ldx xcol
        lda #24
        sec
        sbc heights,x
        sta yrow
.cell:  ldy yrow                ; zp_ptr = screen, zp_col = colour RAM
        lda row_lo,y
        clc
        adc xcol
        sta zp_ptr
        sta zp_col
        lda row_hi,y
        adc #0
        sta zp_ptr+1
        adc #>(COLOR_RAM-SCREEN)
        sta zp_col+1
        ldy #0
        lda #$a0
        sta (zp_ptr),y
        lda #DARK_GREY
        sta (zp_col),y
        lda xcol                ; window?
        and yrow
        and #1
        beq .next
        ldx xcol                ; not on the roof row
        lda #24
        sec
        sbc heights,x
        cmp yrow
        beq .next
        lda #BLACK
        sta (zp_col),y
        ldx nwin
        lda zp_col
        sta win_lo,x
        lda zp_col+1
        sta win_hi,x
        inc nwin
.next:  inc yrow
        lda yrow
        cmp #25
        bne .cell
        inc xcol
        lda xcol
        cmp #40
        bne .col
        rts

nmi:    rti

row_lo: !for r, 0, 24 { !byte <(SCREEN+r*40) }
row_hi: !for r, 0, 24 { !byte >(SCREEN+r*40) }

heights: ; skyline: groups of 3-5 columns, 4 to 10 rows high (0 = gap)
        !byte 6,6,6,0,9,9,9,9,0,4,4,4,0,10,10,10,10,10,0,5,5,5
        !byte 0,8,8,8,8,0,3,3,3,0,7,7,7,7,7,0,6,6

; star positions in colour RAM: pseudo-random, spread over the sky rows
star_lo: !for i, 0, STARS-1 { !byte <(COLOR_RAM + (i*373+29) % (SKY_ROWS*40)) }
star_hi: !for i, 0, STARS-1 { !byte >(COLOR_RAM + (i*373+29) % (SKY_ROWS*40)) }

win_lo = $3000                  ; 256-byte tables filled at start-up
win_hi = $3100
