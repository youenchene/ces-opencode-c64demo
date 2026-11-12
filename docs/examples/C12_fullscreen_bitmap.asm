; =============================================================================
; C12_fullscreen_bitmap.asm - C12 Fullscreen bitmap part
; What you see: a hires bitmap of diagonal stripes covered by colour rings
; that flow outward over the whole picture, with the side borders (and the
; upper/lower borders) opened: copper bars run in the side borders.
; How:
; - side borders: on each of the 200 display lines, $d016 goes to 38 columns
;   with the write on cycle 56 and back to 40 columns at cycle 62. Stable
;   raster (double IRQ) then an unrolled 8-line block: on a normal line the
;   code is 63 cycles; on the badline the 'stx $d016' is placed so its
;   opcode+low byte run at cycles 10-11, the VIC halts the CPU on the high
;   byte read, which resumes at cycle 55 -> the write still lands on 56
; - the free ~43 cycles of each line set $d021: in the opened side borders
;   the VIC shows the background colour -> bars outside the bitmap
; - upper/lower border: 24-row mode ($d011 bit 3 = 0) is set at line $fb,
;   after the 24-row compare line ($f7), so the border never closes
; - speedcode: at start a generator writes 1000 'lda ctab+dist,x / sta
;   screen+i' pairs (6 KB at $4000); each frame the main loop calls it with
;   x = time: screen RAM (hires colours) = ring pattern of distance - time
; Docs: docs/08-effects-library.md (C12), see also C1 and B17
; Based on: codebase64 base:removing_the_sideborders / base:fullscreen /
;           base:speedcode (ideas), rewritten
; Limitations: the side borders are only opened on the 200 display lines
; (top/bottom border area keeps its side borders); no sprites in the
; borders (they would steal cycles and need a different timing per line).
; Cycle-exact: tested in VICE x64sc only, real-hardware check needed.
; =============================================================================
!source "c64.asm"

!ifndef ENTRY { ENTRY = 119 }   ; cycles from stable point to block start (VICE-calibrated)
IRQ_LINE = $2f                  ; double IRQ: $2f then $30
BITMAP  = $2000
SPEED   = $4000                 ; generated speedcode (6001 bytes)
FIRSTBL = $33                   ; first badline (YSCROLL 3)

zp_cnt  = $20                   ; blocks left (25)
zp_t    = $21                   ; time
zp_src  = $22                   ; 2 bytes
zp_dst  = $24                   ; 2 bytes
zp_scr  = $26                   ; 2 bytes
zp_bar  = $28                   ; bar phase

        +basic_upstart

start:
        +demo_init nmi
        jsr gen_speedcode
        lda #RED
        sta BORDER
        lda #BLACK
        sta BACKGROUND
        lda #0
        sta $3fff               ; idle graphics (open upper/lower border)
        lda #$18                ; screen $0400, bitmap $2000
        sta VIC_MEMPTR
        lda #$08                ; hires, 40 columns
        sta VIC_CTRL2
        lda #$3b                ; bitmap, 25 rows, YSCROLL 3
        sta VIC_CTRL1
        +set_irq irq1, IRQ_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag
        beq main
        lda #0
        sta frame_flag
        dec zp_t
        ldx zp_t
        jsr SPEED               ; 1000 colour cells, ~8000 cycles
        jmp main

; ---- speedcode generator: per cell i, 'lda ctab+dist[i],x' 'sta SCREEN+i' --------
gen_speedcode:
        lda #<dist
        sta zp_src
        lda #>dist
        sta zp_src+1
        lda #<SPEED
        sta zp_dst
        lda #>SPEED
        sta zp_dst+1
        lda #<SCREEN
        sta zp_scr
        lda #>SCREEN
        sta zp_scr+1
.cell:  ldy #0
        lda #$bd                ; LDA abs,X
        sta (zp_dst),y
        lda (zp_src),y          ; operand = ctab + dist
        clc
        adc #<ctab
        iny
        sta (zp_dst),y
        lda #>ctab
        adc #0
        iny
        sta (zp_dst),y
        lda #$8d                ; STA abs
        iny
        sta (zp_dst),y
        lda zp_scr
        iny
        sta (zp_dst),y
        lda zp_scr+1
        iny
        sta (zp_dst),y
        lda zp_dst              ; dst += 6
        clc
        adc #6
        sta zp_dst
        bcc +
        inc zp_dst+1
+       inc zp_src
        bne +
        inc zp_src+1
+       inc zp_scr
        bne +
        inc zp_scr+1
+       lda zp_scr
        cmp #<(SCREEN + 1000)
        bne .cell
        lda zp_scr+1
        cmp #>(SCREEN + 1000)
        bne .cell
        ldy #0
        lda #$60                ; RTS
        sta (zp_dst),y
        rts

nmi:    rti
frame_flag: !byte 0

; exact delay of .n cycles (.n >= 2), X must end at 0 -> only nop/bit
!macro delay .n {
        !if .n & 1 {
                bit $00
                !for i, 1, (.n - 3) / 2 { nop }
        } else {
                !for i, 1, .n / 2 { nop }
        }
}

; -----------------------------------------------------------------------------
; Raster code. Line segment (normal line), cycles:
;   lda bars,y 63-3 | sta $d021 4-7 | iny 8-9 | delay 10-52 |
;   stx $d016 53-56 (W56: 38 col) | lda #8 57-58 | sta $d016 59-62 (40 col)
; -----------------------------------------------------------------------------
        !align 255, 0
irq1:
        sta save_a              ; 1st IRQ: 0..7 cycles jitter
        stx save_x
        sty save_y
        lda #<irq2
        sta IRQ_VECTOR
        lda #>irq2
        sta IRQ_VECTOR+1
        inc VIC_RASTER
        asl VIC_IRQ_STATUS
        tsx
        cli
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
irq2:
        txs
        ldx #$08
-       dex
        bne -
        bit $00
        lda VIC_RASTER
        cmp VIC_RASTER
        beq +
+                               ; ---- stable from here ----
!if >* != >irq1 { !error "stable-raster branches cross a page" }
        lda #$3b                ; 25 rows again (was 24 for the open border)
        sta VIC_CTRL1
        lda #25
        sta zp_cnt
        ldy zp_bar
        ldx #0                  ; X = $d016 value for 38 columns
        +delay ENTRY - 10
block:                          ; arrives at cycle 3 of a badline
        iny                     ; 2   (badline: no time for a bar)
        nop                     ; 2
        bit $00                 ; 3
        stx VIC_CTRL2           ; 4   op 10, lo 11, halted, hi 55, W56
        lda #$08                ; 2
        sta VIC_CTRL2           ; 4
!for l, 1, 7 {
        lda bars,y              ; 4
        sta BACKGROUND          ; 4
        iny                     ; 2
        !if l < 7 {
                +delay 43
                stx VIC_CTRL2   ; 4   W56
                lda #$08        ; 2
                sta VIC_CTRL2   ; 4   W62
        } else {
                +delay 36
                lda #$08        ; 2
                dec zp_cnt      ; 5   Z flag kept until the beq
                stx VIC_CTRL2   ; 4   W56
                sta VIC_CTRL2   ; 4   W60
        }
}
        beq +                   ; 2   cycles 61-62
        jmp block               ; 3   63, 1, 2 -> block at cycle 3
+       lda #$33                ; line $fb: 24 rows -> bottom border stays open
        sta VIC_CTRL1
        lda #BLACK
        sta BACKGROUND
        inc zp_bar
        inc frame_flag
        lda #<irq1
        sta IRQ_VECTOR
        lda #>irq1
        sta IRQ_VECTOR+1
        lda #IRQ_LINE
        sta VIC_RASTER
        asl VIC_IRQ_STATUS
        lda save_a
        ldx save_x
        ldy save_y
        rti

save_a: !byte 0
save_x: !byte 0
save_y: !byte 0

        !align 255, 0
bars:   ; copper colours for the side borders (never RED, the border colour)
!for i, 0, 255 {
        !set k = (i >> 1) & 15
        !byte [6, 14, 3, 1, 3, 14, 6, 0, 9, 8, 10, 7, 1, 7, 10, 8][k]
}
ctab:   ; hires cell colours: high nibble = stripe, low nibble = gaps
!for i, 0, 255 + 64 {
        !set k = (i DIV 3) & 7
        !byte [$1b, $3e, $d5, $7a, $f8, $e6, $ac, $34][k]
}
dist:   ; ring index of every screen cell (pixels are taller than wide: *1.25)
!for r, 0, 24 {
        !for c, 0, 39 {
                !set dx = float(c) - 19.5
                !set dy = (float(r) - 12) * 1.25
                !byte int((dx * dx + dy * dy) ^ 0.5 * 2.4)
        }
}
!if * > BITMAP { !error "code/tables run into the bitmap" }

        * = BITMAP              ; diagonal stripes, 3 px on / 3 px off
!for cell, 0, 999 {
        !for l, 0, 7 {
                !set b = 0
                !for p, 0, 7 {
                        !set x = (cell % 40) * 8 + p
                        !set y = (cell DIV 40) * 8 + l
                        !if ((x + y) % 6) < 3 { !set b = b | ($80 >> p) }
                }
                !byte b
        }
}
