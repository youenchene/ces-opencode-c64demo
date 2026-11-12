; =============================================================================
; B13_fire.asm - B13 Fire
; What you see: flames rising from the bottom 16 rows, black->red->orange->yellow.
; How:
; - heat buffer (40 x 18 bytes, 0..63), one heat value per char cell
; - each frame, top to bottom: heat = (left+below+right of the row under,
;   + two rows under) / 4, minus 1 (cool table); the 2 hidden rows at the
;   bottom are refilled with random hot/cold values (8-bit LFSR)
; - display: multicolour chars, 13 dithered shades between the 4 colours
;   ($d021 black, $d022 red, $d023 orange, colour RAM yellow), char = heat/4
; Docs: docs/08-effects-library.md (B13)
; Based on: codebase64 base:4x4_charset_fire_with_lots_of_colors (idea), rewritten
; Limitations: 1 heat value per char cell (not 4x4 sub-pixels); ~31k cycles
;   per update, so it runs unsynced at ~30 fps.
; =============================================================================
!source "c64.asm"

CHARSET  = $2000
SHADE0   = $60                  ; 13 multicolour shade chars $60-$6c
FIRE     = $3000                ; 18 rows x 40 heat values
FIRE_TOP = 9                    ; first screen row of the fire
TITLE    = SCREEN + 3*40 + 5

zp_rnd   = $20

        +basic_upstart

start:
        +demo_init nmi
        jsr copy_rom_font       ; IRQs are still off here
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #RED
        sta BGCOLOR1
        lda #ORANGE
        sta BGCOLOR2
        lda #$18                ; screen $0400, charset $2000
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        lda #$d8                ; multicolour on, 40 columns
        sta VIC_CTRL2
        lda #$20
        +fill_1000 SCREEN
        lda #$08 | YELLOW       ; bit 3 = multicolour char, colour 7
        +fill_1000 COLOR_RAM
        ldx #29                 ; title in hires white (bit 3 = 0)
-       lda title,x
        sta TITLE,x
        lda #WHITE
        sta COLOR_RAM+TITLE-SCREEN,x
        dex
        bpl -
        lda #0                  ; clear the heat buffer
        tax
-       sta FIRE,x
        sta FIRE+$100,x
        sta FIRE+$200,x
        inx
        bne -
        lda #$5a
        sta zp_rnd

main:
        ; ---- seed the 2 hidden rows with random hot / cold cells ------------
        ldx #79
-       lda zp_rnd              ; 8-bit Galois LFSR, period 255
        asl
        bcc +
        eor #$1d
+       sta zp_rnd
        cmp #$90                ; ~56% hot
        lda #63
        bcc +
        lda #0
+       sta FIRE+16*40,x
        dex
        bpl -
        ; ---- propagate + draw, one unrolled loop per row (top first) --------
!for r, 0, 15 {
        ldx #39
-       lda FIRE+(r+1)*40-1,x   ; 4  below-left (wraps to the row end: fine)
        clc                     ; 2
        adc FIRE+(r+1)*40,x     ; 4  below
        adc FIRE+(r+1)*40+1,x   ; 4  below-right
        adc FIRE+(r+2)*40,x     ; 4  two rows below
        lsr                     ; 2
        lsr                     ; 2  average (max 252/4 = 63)
        tay                     ; 2
        lda cool,y              ; 4
        sta FIRE+r*40,x         ; 5
        tay                     ; 2
        lda heat_chr,y          ; 4
        sta SCREEN+(FIRE_TOP+r)*40,x ; 5
        dex                     ; 2
        bpl -                   ; 3  => 49 cycles per cell
}
        jmp main

nmi:    rti

; ROM font (mixed case set, codes $00-$5f) -> CHARSET. Needs IRQs off.
copy_rom_font:
        lda #$33                ; char ROM at $d000, I/O hidden
        sta CPU_PORT
        ldx #0
-       !for p, 0, 2 {
        lda $d800+p*$100,x
        sta CHARSET+p*$100,x
        }
        inx
        bne -
        lda #BANK_IO_ONLY
        sta CPU_PORT
        rts

title:  !scr "fire: 13 multicolour shades  "

        !align 255, 0
; cool[s] = max(0, s - 3): sets how high the flames reach
cool:   !for s, 0, 63 { !byte (s - 3) * (s > 3) }
; heat_chr[h] = SHADE0 + min(12, h / 4)
heat_chr: !for h, 0, 63 { !byte SHADE0 + (h >> 2) - ((h >> 2) > 12) * ((h >> 2) - 12) }

; ---- multicolour shade chars ----------------------------------------------
; level L: colour pair p = L/4 -> p+1, mixed with a 4x4 Bayer dither at
; (L & 3)/4. Pixel codes: 0 = $d021, 1 = $d022, 2 = $d023, 3 = colour RAM.
!macro mc_row .lvl, .y {
        !set .v = 0
        !for x, 0, 3 {
                !set .a = x xor (.y & 3)
                !set .m = ((.a & 1) << 3) | ((.y & 1) << 2) | (.a & 2) | ((.y >> 1) & 1)
                !set .c = (.lvl >> 2) + (.m < (.lvl & 3) * 4)
                !set .v = .v | (.c << (6 - 2 * x))
        }
        !byte .v
}
        * = CHARSET + SHADE0*8
!for lvl, 0, 12 {
        !for y, 0, 7 { +mc_row lvl, y }
}
