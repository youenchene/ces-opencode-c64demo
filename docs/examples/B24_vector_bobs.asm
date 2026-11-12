; =============================================================================
; B24_vector_bobs.asm - B24 Vector bobs
; What you see: a 3D cube whose 8 corners are balls (sprites), spinning on two
; axes; balls further away are drawn darker.
; Technique:
; - the 8 cube vertices are rotated (Y by a, X by 2a) and projected with
;   perspective at assemble time (!for + sin/cos): 128 frames x 8 vertices of
;   screen X, Y and a depth colour;
; - at run time each frame only copies 8 X/Y/colour values to the VIC.
; Docs: docs/08-effects-library.md (B24)
; Limitations: no depth sorting (sprite 0 is always in front), 8 bobs only
; (more need the B26 multiplexer). X stays below 256: no $d010 handling.
; =============================================================================
!source "c64.asm"

SPRITE_DATA = $2000             ; 64-byte aligned, VIC bank 0
SPRITE_PTRS = SCREEN + $3f8
TABLES      = $2100

frame   = $20                   ; zero page: 0..127

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM
        ldx #title_end-title-1  ; title on row 1
-       lda title,x
        sta SCREEN+40+(40-(title_end-title))/2,x
        dex
        bpl -

        lda #SPRITE_DATA/64     ; same ball for all 8 sprites
        ldx #7
-       sta SPRITE_PTRS,x
        dex
        bpl -
        lda #0
        sta SPR_X_MSB
        sta frame
        lda #$ff
        sta SPR_ENABLE

main:
-       lda VIC_RASTER          ; update below the display
        cmp #$fb
        bne -
        ldx frame
        !for v, 0, 7 {
        lda xtab + v*128,x
        sta SPR0_X + v*2
        lda ytab + v*128,x
        sta SPR0_Y + v*2
        lda ctab + v*128,x
        sta SPR0_COLOR + v
        }
        inx
        txa
        and #127
        sta frame
-       lda VIC_RASTER
        cmp #$fb
        beq -
        jmp main

nmi:    rti

title:  !scr "vector bobs: 8 sprites, 3d precalc"
title_end:

        * = SPRITE_DATA
        ; 16x15 ball, centred on sprite pixel (8,7)
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

        * = TABLES
PI = 3.14159265
; vertex v: x = bit0, y = bit1, z = bit2 (-1 or +1)
; what: 0 = screen X, 1 = screen Y, 2 = colour
!macro cube_table .what {
        !for v, 0, 7 {
        !for f, 0, 127 {
        !set a  = f * 2 * PI / 128
        !set b  = 2 * a
        !set vx = (v & 1) * 2 - 1
        !set vy = ((v >> 1) & 1) * 2 - 1
        !set vz = ((v >> 2) & 1) * 2 - 1
        !set x1 = vx * cos(a) + vz * sin(a)         ; rotate around Y
        !set z1 = vz * cos(a) - vx * sin(a)
        !set y2 = vy * cos(b) - z1 * sin(b)         ; rotate around X
        !set z2 = vy * sin(b) + z1 * cos(b)
        !set p  = 4.0 / (5.0 + z2)                  ; perspective
        !if .what = 0 { !byte int(184 - 8 + 40 * x1 * p) }
        !if .what = 1 { !byte int(150 - 7 + 40 * y2 * p) }
        !if .what = 2 {
                !set d = int((z2 + 1.75) / 0.875)   ; 0 = near .. 3 = far
                !byte (d = 0) * WHITE + (d = 1) * LIGHT_GREY + (d = 2) * GREY + (d >= 3) * DARK_GREY
        }
        }
        }
}
xtab:   +cube_table 0
ytab:   +cube_table 1
ctab:   +cube_table 2
