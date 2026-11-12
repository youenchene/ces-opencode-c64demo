; =============================================================================
; B26_sprite_multiplexer.asm - B26 Simple sprite multiplexer
; What you see: 32 balls (4 rows of 8) waving on sine curves, with only the
; 8 hardware sprites.
; Technique:
; - the screen is split into 4 fixed Y bands, 50 lines apart; each band's
;   sprites only move 0..14 lines inside their band;
; - a raster IRQ just below each band's sprites (band top + 37) rewrites the
;   8 X/Y/colour registers for the next band; the VIC then draws the same
;   8 sprites again further down. No sorting needed with fixed bands;
; - the main loop computes the 32 positions from sine tables once per frame.
; Docs: docs/08-effects-library.md (B26)
; Based on: codebase64 base:sprite_multiplexing (band idea), rewritten
; Limitations: fixed bands (sprites can't cross bands), X < 256 (no $d010).
; =============================================================================
!source "c64.asm"

SPRITE_DATA = $2000
SPRITE_PTRS = SCREEN + $3f8
BAND0   = 56                    ; sprite Y of band 0 (sprite top)
BAND_H  = 50                    ; distance between bands
WOBBLE  = 14                    ; Y movement inside a band

frame_flag = $20                ; zero page
phx     = $21
phy     = $22

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #GREY
        +fill_1000 COLOR_RAM
        ldx #title_end-title-1
-       lda title,x
        sta SCREEN+24*40+(40-(title_end-title))/2,x
        dex
        bpl -

        lda #SPRITE_DATA/64
        ldx #7
-       sta SPRITE_PTRS,x
        dex
        bpl -
        lda #0
        sta SPR_X_MSB
        lda #$ff
        sta SPR_ENABLE
        jsr compute

        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_band0, 250
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:
        lda frame_flag          ; set by irq_band0 (bottom of the screen)
        beq main
        lda #0
        sta frame_flag
        jsr compute
        jmp main

; ---- 32 positions: sx[j], sy[j], j = band*8 + sprite ------------------------
compute:
        inc phx
        inc phy
        inc phy
        ldx #31
-       lda offx,x
        clc
        adc phx
        tay
        lda sinx,y
        sta sx,x
        lda offy,x
        clc
        adc phy
        tay
        lda siny,y
        clc
        adc ybase,x
        sta sy,x
        dex
        bpl -
        rts

; ---- one IRQ per band: load the 8 sprites of band .k ----------------------
!macro band .k, .next, .line {
        +irq_enter
        !for i, 0, 7 {
        lda sx + .k*8 + i       ; 4
        sta SPR0_X + i*2        ; 4
        lda sy + .k*8 + i
        sta SPR0_Y + i*2
        }
        lda bandcol + .k
        !for i, 0, 7 { sta SPR0_COLOR + i }
        +set_irq .next, .line
}

irq_band0:                      ; line 250: below the last band
        +band 0, irq_band1, BAND0 + 0*BAND_H + WOBBLE + 23
        inc frame_flag
        +irq_exit
irq_band1:
        +band 1, irq_band2, BAND0 + 1*BAND_H + WOBBLE + 23
        +irq_exit
irq_band2:
        +band 2, irq_band3, BAND0 + 2*BAND_H + WOBBLE + 23
        +irq_exit
irq_band3:
        +band 3, irq_band0, 250
        +irq_exit

nmi:    rti

title:  !scr "32 sprites with 8: 4 raster bands"
title_end:
bandcol: !byte LIGHT_RED, YELLOW, LIGHT_GREEN, LIGHT_BLUE

PI = 3.14159265
offx:   !for j, 0, 31 { !byte ((j & 7) * 26 + (j >> 3) * 40) & 255 }
offy:   !for j, 0, 31 { !byte ((j & 7) * 32 + (j >> 3) * 64) & 255 }
ybase:  !for j, 0, 31 { !byte BAND0 + (j >> 3) * BAND_H }
sx:     !fill 32, 0
sy:     !fill 32, 0
        !align 255, 0
sinx:   !for i, 0, 255 { !byte int(150.5 + 100 * sin(i * 2 * PI / 256)) }
siny:   !for i, 0, 255 { !byte int(WOBBLE / 2 + 0.5 + WOBBLE / 2 * sin(i * 2 * PI / 256)) }

        * = SPRITE_DATA
        !byte %.....###, %###....., %........
        !byte %...#####, %#####..., %........
        !byte %..######, %######.., %........
        !byte %.#######, %#######., %........
        !byte %.#######, %#######., %........
        !byte %########, %########, %........
        !byte %########, %########, %........
        !byte %########, %########, %........
        !byte %########, %########, %........
        !byte %########, %########, %........
        !byte %.#######, %#######., %........
        !byte %.#######, %#######., %........
        !byte %..######, %######.., %........
        !byte %...#####, %#####..., %........
        !byte %.....###, %###....., %........
        !fill 6*3+1, 0
