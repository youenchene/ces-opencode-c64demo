; =============================================================================
; C02_tech_tech.asm - C2 Tech-tech
; What you see: a big "OPENCODE" logo (48 pixel lines) where every raster line
;   is shifted horizontally on its own, so the logo waves like a flag, with an
;   amplitude of 56 pixels.
; Technique:
;   - the logo is a 40x6 char block, every cell has its own char code
;     (row*40+col). 7 charsets hold the logo pre-shifted by 0..6 chars
;   - per raster line: $d016 = fine shift (0-7 px), $d018 = charset (coarse
;     shift in chars). A charset switch acts at once, no badline needed
;   - both writes land in the right border (cycle ~55-63), stable raster
;     (double IRQ), loop unrolled per char row: 1 badline + 7 normal lines
;   - per-line tables are rebuilt from a sine each frame in the main loop
;   - the logo is generated at start-up from the ROM font (x4 wide, x6 high)
; Docs: docs/08-effects-library.md (C2)
; Based on: C=Hacking #7 "tech-tech" article (cb:magazines:chacking7), rewritten
; Limitations: amplitude limited to 0..55 px (7 charsets fit in VIC bank 1).
;   Timing tuned in VICE (x64sc); untested on real hardware.
; =============================================================================
!source "c64.asm"

IRQ_LINE  = $6e                 ; double IRQ: $6e/$6f, stable during $70
LOGO_ROW  = 8                   ; first char row (badline $73)
LINES     = 48
!ifndef PRE { PRE = 40 }        ; stable point -> cycle ~55 of line $72
!ifndef DB  { DB  = 2 }         ; padding on badlines
!ifndef DBG { DBG = 0 }         ; 1: show write position as border colour

VSCREEN   = $4000               ; bank 1: screen $4000, charsets $4800..$7800
CHARSETS  = $4800
LOGO      = $3000               ; 6 rows * 256 bytes, generated (bank 0)

ptr       = $20                 ; 2 bytes
src       = $22                 ; 2 bytes
cnt       = $24
ycnt      = $25
q         = $26
tmpb      = $27
phase     = $28

; delay of .n cycles (.n = 2..255), clobbers Y
!macro delay .n {
        !if .n >= 11 {
                !set .k = (.n - 1) / 5
                !set .r = .n - (5 * .k + 1)
                !if .r = 1 { !set .k = .k - 1 : !set .r = 6 }
                ldy #.k         ; 5k+1 cycles
.l              dey
                bne .l
                !if >.l != >* { !error "delay loop crosses a page" }
        } else { !set .r = .n }
        !if .r & 1 { bit $ea : !set .r = .r - 3 }
        !for .i, 1, .r / 2 { nop }
}

; one line: both register writes in the right border, 22 cycles
!macro wline {
        lda d016v,x             ; 4
        ldy d018v,x             ; 4
        sta VIC_CTRL2           ; 4
        sty VIC_MEMPTR          ; 4
        !if DBG { stx BORDER } else { bit BORDER } ; 4
        inx                     ; 2
}

        +basic_upstart

start:
        +demo_init nmi
        jsr build_logo
        jsr build_charsets
        lda #$ff                ; screen: blank code everywhere...
        +fill_1000 VSCREEN
        ldx #0                  ; ...logo block = codes 0..239
-       txa
        sta VSCREEN+LOGO_ROW*40,x
        inx
        cpx #240
        bne -
        ldx #39                 ; one colour per char row
-       !for r, 0, 5 { lda #[7, 1, 3, 14, 4, 6][r] : sta COLOR_RAM+(LOGO_ROW+r)*40,x }
        dex
        bpl -
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$02                ; VIC bank 1 ($4000)
        sta CIA2_PRA
        lda #$02                ; screen $4000, charset $4800
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        jsr make_tables
        +set_irq irq1, IRQ_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag
        beq main
        lda #0
        sta frame_flag
        inc phase
        inc phase
        jsr make_tables
        jmp main

; offset = sine(phase + 5*i) + sine2(2*phase - 3*i), 0..55 px per line
make_tables:
        ldx #0
        lda phase
        sta tmpb
        asl
        sta q
-       ldy tmpb
        lda sine1,y
        ldy q
        clc
        adc sine2,y
        tay
        and #7
        ora #$c8                ; 40 columns + fine shift
        sta d016v,x
        tya
        lsr
        lsr
        lsr                     ; coarse 0..6
        clc
        adc #1                  ; charset slot 1..7 ($4800..$7800)
        asl
        sta d018v,x             ; screen slot 0
        lda tmpb
        clc
        adc #5
        sta tmpb
        lda q
        sec
        sbc #3
        sta q
        inx
        cpx #LINES
        bne -
        rts

; ---- logo: "OPENCODE", ROM glyph pixels scaled x4 wide, x6 high -----------
build_logo:
        lda #$33                ; char ROM visible (IRQs are off)
        sta CPU_PORT
        ldx #63
-       lda text,x              ; text,x = screen code of letter x/8
        asl
        asl
        asl
        sta src
        lda #0
        rol                     ; codes < $20 -> carry always 0 here
        ora #$d0
        sta src+1
        txa
        and #7
        tay
        lda (src),y
        sta glyph,x
        dex
        bpl -
        lda #BANK_IO_ONLY
        sta CPU_PORT

        lda #0
        sta ycnt                ; logo pixel row 0..47
.row:   lda ycnt
        and #7
        sta ptr
        lda ycnt
        lsr
        lsr
        lsr
        clc
        adc #>LOGO
        sta ptr+1
        lda #0
        sta cnt                 ; cell column 0..31
.col:   lda cnt
        and #3
        sta q
        lda cnt                 ; glyph index = letter*8 + row/6
        and #$1c
        asl
        ldx ycnt
        clc
        adc div6,x
        tax
        lda glyph,x
        ldx q                   ; take bits 7-2q, 6-2q
-       cpx #0
        beq +
        asl
        asl
        dex
        bne -
+       rol
        rol
        rol
        and #3
        tax
        lda expand,x
        tay
        lda cnt
        asl
        asl
        asl
        sty tmpb
        tay
        lda tmpb
        sta (ptr),y
        inc cnt
        lda cnt
        cmp #32
        bne .col
        inc ycnt
        lda ycnt
        cmp #LINES
        bne .row
        rts

; ---- 7 charsets: clear, then logo rows shifted by k chars ------------------
build_charsets:
        lda #0
        tay
        ldx #>CHARSETS
-       stx ptr+1
        sty ptr
        sta (ptr),y             ; y=0 here: use a full-page loop instead
        ldy #0
--      sta (ptr),y
        iny
        bne --
        inx
        cpx #$80
        bne -
        lda #0
        sta cnt                 ; k = 0..6
.k:     lda #0
        sta ycnt                ; r = 0..5
        lda cnt                 ; ptr = CHARSETS + k*$800 + k*8
        asl
        asl
        asl
        sta ptr
        lda cnt
        asl
        asl
        asl
        clc
        adc #>CHARSETS
        sta ptr+1
.r:     lda ycnt
        clc
        adc #>LOGO
        sta src+1
        lda #0
        sta src
        ldy #0
-       lda (src),y
        sta (ptr),y
        iny
        bne -
        lda ptr                 ; next char row: +40 chars = +320 bytes
        clc
        adc #<320
        sta ptr
        lda ptr+1
        adc #>320
        sta ptr+1
        inc ycnt
        lda ycnt
        cmp #6
        bne .r
        inc cnt
        lda cnt
        cmp #7
        bne .k
        rts

nmi:    rti

; -----------------------------------------------------------------------------
; Timing-critical code, kept inside one page
; -----------------------------------------------------------------------------
        !align 255, 0
irq1:   sta save_a
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
irq2:   txs
        ldx #$08
-       dex
        bne -
        bit $00
        lda VIC_RASTER
        cmp VIC_RASTER
        beq +
+       +delay PRE              ; ---- stable ----
        ldx #0
row:    +wline                  ; writes for the badline (end of prev line)
        +delay DB               ; badline: VIC takes cycles 12..54
        !for l, 1, 6 { +wline : +delay 41 }
        +wline
        +delay 33
        cpx #LINES              ; 2
        beq +                   ; 2
        jmp row                 ; 3
+

        lda #<irq1
        sta IRQ_VECTOR
        lda #>irq1
        sta IRQ_VECTOR+1
        lda #IRQ_LINE
        sta VIC_RASTER
        asl VIC_IRQ_STATUS
        inc frame_flag
        lda #BLACK
        sta BORDER
        lda save_a
        ldx save_x
        ldy save_y
        rti

save_a: !byte 0
save_x: !byte 0
save_y: !byte 0
frame_flag: !byte 0

        !align 255, 0
d016v:  !fill LINES, $c8
d018v:  !fill LINES, $02
glyph:  !fill 64, 0
expand: !byte $00, $0f, $f0, $ff
div6:   !for i, 0, LINES-1 { !byte i / 6 }
text:   !for i, 0, 7 { !fill 8, [15, 16, 5, 14, 3, 15, 4, 5][i] }
        !align 255, 0
sine1:  !for i, 0, 255 { !byte int(16 + 15.5 * sin(float(i) * 2 * 3.14159265 / 256)) }
sine2:  !for i, 0, 255 { !byte int(12 + 11.5 * sin(float(i) * 2 * 3.14159265 / 256)) }
