; =============================================================================
; C03_dysp.asm - C3 DYSP (Different Y Sprite Positions) in the open side border
; What you see: the 8 letters of "OPENCODE" (X-expanded sprites) flying on
;   their own X and Y sines across a 100-line band where the side borders are
;   open, so the letters glide through the left and right borders.
; Technique:
;   - same band loop as C01: stable raster, FLD (no badlines), dec/inc $d016
;     at the right border edge on every line
;   - the problem: a sprite starting on a given line changes the cycles left
;     to the CPU on that line. Fix ($d017 trick): all 8 sprites start on the
;     first band line and stay active for the whole band -> constant timing
;   - every line: $d017=0 (sets each Y-expand flip-flop), then $d017=mask:
;     a set bit makes the VIC repeat the current sprite row on the next line.
;     Sprite i repeats its blank row 0 until line y(i), shows rows 1-19, then
;     repeats its blank row 20 until the band ends
;   - the mask table (100 bytes) is rebuilt each frame from a Y sine
; Docs: docs/08-effects-library.md (C3)
; Based on: codebase64 base:dysp_d017 by Compyx, rewritten
; Limitations: band height fixed (100 lines), letters move 0..79 lines inside
;   it. Timing taken from C01, tuned in VICE (x64sc); untested on real hardware.
; =============================================================================
!source "c64.asm"

IRQ_LINE  = $7a                 ; 1st IRQ; the band starts at SPR_Y
SPR_Y     = $7d                 ; all 8 sprites start on the first band line
PRE       = 56                  ; cycles between stable point and band loop
BAND      = 100                 ; lines in the band
YRANGE    = BAND - 21           ; Y offset 0..78
SPRDATA   = $2000               ; 8 sprite shapes (pointers $80-$87)

phase     = $20                 ; zero page
phase2    = $21
msb       = $22
ptr       = $23                 ; 2 bytes
cnt       = $25
lo        = $26
hi        = $27
gb        = $28

        +basic_upstart

start:
        +demo_init nmi
        jsr build_sprites
        lda #BLUE
        sta BORDER
        lda #BLACK
        sta BACKGROUND
        sta $3fff               ; idle graphics byte (shown in FLD lines)
        lda #$20
        +fill_1000 SCREEN
        lda #GREY
        +fill_1000 COLOR_RAM
        ldx #39
-       lda text1,x
        sta SCREEN+5*40,x
        lda text2,x
        sta SCREEN+7*40,x
        dex
        bpl -
        lda #$1b
        sta VIC_CTRL1
        lda #$c8
        sta VIC_CTRL2
        lda #$15
        sta VIC_MEMPTR

        ldx #7
-       txa
        clc
        adc #SPRDATA/64
        sta SCREEN+$3f8,x
        lda spr_col,x
        sta SPR0_COLOR,x
        dex
        bpl -
        ldx #14
-       lda #SPR_Y
        sta SPR0_Y,x
        dex
        dex
        bpl -
        lda #$ff
        sta SPR_ENABLE
        sta SPR_EXPAND_X
        jsr move

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
        inc phase2
        inc phase2
        jsr move
        jmp main

; X from a 9-bit sine, Y mask table from a second sine
move:   lda #$ff                ; all bits set = "repeat this row"
        ldx #BAND-1
-       sta d017_tab,x
        dex
        bpl -
        lda #0
        sta msb
        ldx #7
.spr:   txa                     ; X: phase + 32*i
        asl
        asl
        asl
        asl
        asl
        clc
        adc phase
        tay
        txa
        asl
        sta cnt                 ; register offset 2*i
        lda sinx_hi,y
        lsr                     ; 9th bit -> carry
        rol msb                 ; sprite 7 shifted in first
        lda sinx_lo,y
        ldy cnt
        sta SPR0_X,y
        txa                     ; Y: phase2 + 24*i
        asl
        asl
        asl
        sta cnt
        asl
        adc cnt
        adc phase2
        tay
        lda siny,y              ; first shown line (0..YRANGE-1)
        tay
        lda bit_clr,x
        sta gb
        lda #19                 ; clear bit i on 19 lines: rows 1..19 advance
        sta cnt
-       lda d017_tab,y
        and gb
        sta d017_tab,y
        iny
        dec cnt
        bne -
        dex
        bpl .spr
        lda msb
        sta SPR_X_MSB
        rts

; 8 letters from the ROM font, 2x2 scaled into rows 2..17 of each sprite
build_sprites:
        lda #0
        tax
-       sta SPRDATA,x
        sta SPRDATA+$100,x
        inx
        bne -
        lda #$33                ; char ROM visible (IRQs are off)
        sta CPU_PORT
        lda #0
        sta cnt                 ; byte index: letter*8 + row
.b:     lda cnt
        lsr
        lsr
        lsr
        tax
        lda text_codes,x        ; glyph address = $d000 + code*8 (codes < 32)
        asl
        asl
        asl
        sta ptr
        lda #$d0
        sta ptr+1
        lda cnt
        and #7
        tay
        lda (ptr),y
        sta gb
        ldy #8                  ; double every bit -> 16-bit word hi:lo
-       asl gb
        php
        rol lo
        rol hi
        plp
        rol lo
        rol hi
        dey
        bne -
        lda cnt                 ; dest = SPRDATA + letter*64 + (2+2*row)*3
        and #7
        asl
        clc
        adc #2
        sta ptr
        asl
        adc ptr                 ; *3
        sta ptr
        lda cnt
        and #$38
        asl
        asl
        asl                     ; letter*64 (low byte, letter 0..3)
        php
        clc
        adc ptr
        tay
        lda #>SPRDATA
        adc #0
        plp
        adc #0                  ; letters 4..7 -> +$100
        sta ptr+1
        lda #<SPRDATA
        sta ptr
        lda hi
        sta (ptr),y
        iny
        lda lo
        sta (ptr),y
        iny
        iny
        lda hi                  ; same row again (2x high)
        sta (ptr),y
        iny
        lda lo
        sta (ptr),y
        inc cnt
        lda cnt
        cmp #64
        bne .b
        lda #BANK_IO_ONLY
        sta CPU_PORT
        rts

nmi:    rti

; -----------------------------------------------------------------------------
; Timing-critical code, kept inside one page
; -----------------------------------------------------------------------------
        !align 255, 0
irq1:   sta save_a              ; 0..7 cycles jitter
        stx save_x
        sty save_y
        lda #$ff                ; every sprite starts by repeating row 0
        sta SPR_EXPAND_Y
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
irq2:   txs                     ; 0..1 cycle jitter
        ldx #$08
-       dex
        bne -
        bit $00
        lda VIC_RASTER
        cmp VIC_RASTER
        beq +                   ; removes the last cycle of jitter
+                               ; ---- stable from here ----
        !for i, 1, (PRE-2)/2 { nop }   ; C01 delay minus the extra ldy
        ldx #0                  ; 2
        ldy #0                  ; 2
band:   lda d011_tab,x          ; 4   FLD: no badline in the band
        sta VIC_CTRL1           ; 4
        dec VIC_CTRL2           ; 6   38 columns exactly at the right edge
        inc VIC_CTRL2           ; 6   back to 40 columns
        sty SPR_EXPAND_Y        ; 4   all flip-flops set
        lda d017_tab,x          ; 4
        sta SPR_EXPAND_Y        ; 4   set bits: repeat row on the next line
        bit $ea                 ; 3
        nop                     ; 2
        nop                     ; 2
        inx                     ; 2
        cpx #BAND               ; 2
        bne band                ; 3   = 46 CPU cycles (+17 lost to sprites)

        sty SPR_EXPAND_Y        ; let the sprites finish (blank row 20)
        lda #$1b
        sta VIC_CTRL1
        lda #<irq1
        sta IRQ_VECTOR
        lda #>irq1
        sta IRQ_VECTOR+1
        lda #IRQ_LINE
        sta VIC_RASTER
        asl VIC_IRQ_STATUS
        inc frame_flag
        lda save_a
        ldx save_x
        ldy save_y
        rti
irq_end:
!if >irq1 != >irq_end { !error "timing code crosses a page" }

save_a: !byte 0
save_x: !byte 0
save_y: !byte 0
frame_flag: !byte 0

        !align 255, 0
d011_tab:                       ; yscroll never equal to raster&7 -> no badline
        !for i, 0, BAND-1 { !byte $18 | ((IRQ_LINE + 4 + i + 4) & 7) }
        !align 127, 0
d017_tab: !fill BAND+20, $ff
bit_clr: !byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f
spr_col: !byte 1, 7, 13, 3, 15, 10, 14, 5
text_codes: !byte 15, 16, 5, 14, 3, 15, 4, 5      ; O P E N C O D E
text1:  !scr "      dysp: sprites in the side border  "
text2:  !scr "----------------------------------------"

        !align 255, 0           ; X: 0..440 (sprite X), Y: 0..YRANGE-1
sinx_lo: !for i, 0, 255 { !byte <int(220 + 210 * sin(float(i) * 2 * 3.14159265 / 256)) }
sinx_hi: !for i, 0, 255 { !byte >int(220 + 210 * sin(float(i) * 2 * 3.14159265 / 256)) }
siny:    !for i, 0, 255 { !byte int((YRANGE - 1) / 2 + (YRANGE - 1) / 2 * sin(float(i) * 2 * 3.14159265 / 256)) }
