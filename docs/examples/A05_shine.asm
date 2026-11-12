; =============================================================================
; A05_shine.asm - A5 Shine / glint
; What you see: a light blue "OPENCODE" block logo; a white diagonal glint
;   sweeps across it about every 1.3 s.
; Technique:
; - same as A4 (colour cycling), with a 64-entry gradient that is mostly the
;   logo colour and holds a short bright band (cyan, white, cyan)
; - colour[r][x] = gradient[(x + r + phase) & 63]: the +r tilts the band
; - phase-- moves the band to the right; 64 > logo width + height, so there
;   is a pause between two glints
; - the logo is built from solid blocks (screen code $a0) out of '#' strings
; Docs: docs/08-effects-library.md (A5). Same idea as ces_shine in src/main.asm
; =============================================================================
!source "c64.asm"

LOGO_W   = 31
LOGO_H   = 5
LOGO_ROW = 9
LOGO_COL = (40 - LOGO_W) / 2

zp_phase = $20
zp_tmp   = $21

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$17                ; ROM font lower/upper case
        sta VIC_MEMPTR
        lda #$20
        +fill_1000 SCREEN
        lda #GREY
        +fill_1000 COLOR_RAM

        !for r, 0, LOGO_H - 1 { ; '#' -> solid block, anything else stays a space
        ldx #LOGO_W-1
-       lda logo+r*LOGO_W,x
        cmp #'#'
        bne +
        lda #$a0
        sta SCREEN+(LOGO_ROW+r)*40+LOGO_COL,x
+       dex
        bpl -
        }
        ldx #caption_end-caption-1
-       lda caption,x
        sta SCREEN+18*40+(40-(caption_end-caption))/2,x
        dex
        bpl -

main_loop:
-       lda VIC_RASTER          ; wait for line $ff (bottom border)
        cmp #$ff
        bne -
        jsr shine
-       lda VIC_RASTER
        cmp #$ff
        beq -
        jmp main_loop

shine:                          ; ~3.5k cycles
        dec zp_phase
        ldx #LOGO_W-1
-       txa
        clc
        adc zp_phase
        sta zp_tmp
        !for r, 0, LOGO_H - 1 {
        lda zp_tmp
        clc
        adc #r
        and #63
        tay
        lda shine_gradient,y
        sta COLOR_RAM+(LOGO_ROW+r)*40+LOGO_COL,x
        }
        dex
        bmi +
        jmp -                   ; unrolled body is too long for a branch
+       rts

nmi:    rti

shine_gradient: ; 64 entries: light blue with a short white glint
        !for i, 0, 49 { !byte LIGHT_BLUE }
        !byte $03,$03,$0d,$01,$01,$01,$01,$0d,$03,$03
        !for i, 0, 3 { !byte LIGHT_BLUE }

logo:   ; 5 rows x 31 columns, '#' = block
        !text "### ### ### ##  ### ### ##  ###"
        !text "# # # # #   # # #   # # # # #  "
        !text "# # ### ##  # # #   # # # # ## "
        !text "# # #   #   # # #   # # # # #  "
        !text "### #   ### # # ### ### ##  ###"

caption: !scr "a white glint crosses the logo"
caption_end:
