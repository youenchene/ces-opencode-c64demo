; =============================================================================
; A04_color_cycle_text.asm - A4 Colour cycling text
; What you see: three text rows, each with a colour gradient flowing through
;   the letters (blue/white to the left, fire to the right, green faster).
; Technique:
; - the characters never change: only colour RAM ($d800) is rewritten
; - colour[x] = gradient[(x + phase) & 15], one 16-byte gradient per row
; - phase++ moves the gradient left, phase-- moves it right
; - main loop synced on raster line $ff (no IRQ needed), ~0.6k cycles per row
; Docs: docs/08-effects-library.md (A4)
; =============================================================================
!source "c64.asm"

ROW1 = 8
ROW2 = 12
ROW3 = 16

zp_p1 = $20                     ; phases, one per row
zp_p2 = $21
zp_p3 = $22

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$17                ; screen $0400, ROM font lower/upper case
        sta VIC_MEMPTR
        lda #$20
        +fill_1000 SCREEN
        lda #DARK_GREY
        +fill_1000 COLOR_RAM
        ldx #39                 ; texts are exactly 40 chars
-       lda text1,x
        sta SCREEN+ROW1*40,x
        lda text2,x
        sta SCREEN+ROW2*40,x
        lda text3,x
        sta SCREEN+ROW3*40,x
        dex
        bpl -

main_loop:
-       lda VIC_RASTER          ; wait for line $ff (bottom border)
        cmp #$ff
        bne -
        inc zp_p1               ; row 1 flows left
        dec zp_p2               ; row 2 flows right
        inc zp_p3               ; row 3 flows left, twice as fast
        inc zp_p3

        ldx #39
-       txa
        clc
        adc zp_p1
        and #15
        tay
        lda grad1,y
        sta COLOR_RAM+ROW1*40,x
        txa
        clc
        adc zp_p2
        and #15
        tay
        lda grad2,y
        sta COLOR_RAM+ROW2*40,x
        txa
        clc
        adc zp_p3
        and #15
        tay
        lda grad3,y
        sta COLOR_RAM+ROW3*40,x
        dex
        bpl -

-       lda VIC_RASTER          ; wait until we left line $ff
        cmp #$ff
        beq -
        jmp main_loop

nmi:    rti

grad1:  !byte $06,$06,$0e,$0e,$03,$03,$01,$01,$01,$03,$03,$0e,$0e,$06,$06,$06
grad2:  !byte $02,$02,$08,$08,$0a,$0a,$07,$07,$01,$07,$07,$0a,$0a,$08,$08,$02
grad3:  !byte $0b,$05,$05,$0d,$0d,$01,$01,$0d,$0d,$05,$05,$0b,$0b,$0c,$0f,$0c

;              0123456789012345678901234567890123456789
text1:  !scr "    codeurs en seine 2026 - rouen       "
text2:  !scr "  colour cycling: only $d800 changes    "
text3:  !scr "     opencode on a commodore 64 !       "
