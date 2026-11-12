; =============================================================================
; B11_colour_plasma.asm - B11 Colour plasma
; What you see: smooth flowing colour waves over the whole screen.
; How:
; - every screen cell holds $a0 (solid block in the ROM font), so the picture
;   is made by colour RAM only
; - xbuf[x] = sin[x*3+a] + sin[x*5+b], ybuf[y] = sin[y*4+c] + sin[y*7+d] + t
; - colour RAM = pal[xbuf[x] + ybuf[y]], 25 unrolled row loops (24 cycles/cell)
; - a, b, c, d move at different speeds; t cycles the palette
; Docs: docs/08-effects-library.md (B11)
; Based on: codebase64 base:colorcycleplasma, rewritten
; Limitations: a full screen takes ~25k cycles (about 1.3 frames), so the
;   plasma runs unsynced at ~35 fps; a little tearing is possible.
; =============================================================================
!source "c64.asm"

zp_i1   = $20                   ; running sine indexes
zp_i2   = $21
zp_pa   = $22                   ; phases
zp_pb   = $23
zp_pc   = $24
zp_pd   = $25
zp_t    = $26

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$15                ; screen $0400, ROM font (upper case)
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        lda #$c8
        sta VIC_CTRL2
        lda #$a0                ; solid block everywhere
        +fill_1000 SCREEN
        lda #BLACK
        +fill_1000 COLOR_RAM

        ; pal[i] = ramp[(i >> 3) & 15]  (2 full colour ramps over 256 values)
        ldx #0
-       txa
        lsr
        lsr
        lsr
        and #15
        tay
        lda ramp,y
        sta pal,x
        inx
        bne -

main:
        ; ---- xbuf[x] = sin[a + 3x] + sin[b + 5x] -------------------------
        lda zp_pa
        sta zp_i1
        lda zp_pb
        sta zp_i2
        ldx #0
-       ldy zp_i1
        lda sine,y
        ldy zp_i2
        clc
        adc sine,y
        sta xbuf,x
        lda zp_i1
        clc
        adc #3
        sta zp_i1
        lda zp_i2
        clc
        adc #5
        sta zp_i2
        inx
        cpx #40
        bne -
        ; ---- ybuf[y] = sin[c + 4y] + sin[d + 7y] + t ----------------------
        lda zp_pc
        sta zp_i1
        lda zp_pd
        sta zp_i2
        ldx #0
-       ldy zp_i1
        lda sine,y
        ldy zp_i2
        clc
        adc sine,y
        clc
        adc zp_t
        sta ybuf,x
        lda zp_i1
        clc
        adc #4
        sta zp_i1
        lda zp_i2
        clc
        adc #7
        sta zp_i2
        inx
        cpx #25
        bne -

        ; ---- render: 25 unrolled row loops ----------------------------------
        ; carry is not cleared: a stray +1 is invisible (bands are 8 wide)
!for r, 0, 24 {
        ldx #39
-       lda xbuf,x              ; 4
        adc ybuf+r              ; 4
        tay                     ; 2
        lda pal,y               ; 4
        sta COLOR_RAM+r*40,x    ; 5
        dex                     ; 2
        bpl -                   ; 3  => 24 cycles per cell
}
        ; ---- move the phases ---------------------------------------------
        inc zp_pa
        lda zp_pb
        sec
        sbc #2
        sta zp_pb
        lda zp_pc
        clc
        adc #3
        sta zp_pc
        dec zp_pd
        inc zp_t
        jmp main

nmi:    rti

; brightness ramp black -> blue -> cyan -> white and back
ramp:   !byte 0, 6, 11, 4, 14, 3, 13, 1, 1, 13, 3, 14, 4, 11, 6, 0
xbuf:   !fill 40, 0
ybuf:   !fill 25, 0

        !align 255, 0
sine:   !for i, 0, 255 { !byte int(32 + 31.5 * sin(float(i) * 2 * 3.14159265 / 256)) }
pal:    !fill 256, 0
