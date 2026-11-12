; =============================================================================
; C04_fpp_stretcher.asm - C4 FPP (Flexible Pixel Position) / stretcher
; What you see: a 48-line "OPENCODE" logo that is stretched (1x to 4x),
;   squashed, bounced and bent vertically, every raster line picking any
;   line of the logo, including repeating the same line many times.
; Technique (char-mode FPP):
;   - every raster line of the 120-line area is forced to be a badline
;     ($d011 yscroll = raster & 7). On a badline the VIC resets its row
;     counter to 0 and, as the row never ends, re-reads the SAME screen row:
;     each line shows row 0 of 40 chars
;   - $d018 picks one of 6 screens (different char codes) x 8 charsets
;     (different row-0 bytes) = 48 logo lines, any of them on any raster line
;   - the badline DMA halts the CPU up to cycle 55 on every line, so an
;     unrolled 20-cycle block per line re-syncs itself: no stable raster
;     needed (like FLI)
;   - the 6 screens overlap the charsets: they only use bytes 0-39, i.e. the
;     row-0 bytes of char codes 0-4 and 128-132, which the logo never uses
;   - below the area: ECM+BMM (invalid mode) shows black
; Docs: docs/08-effects-library.md (C4)
; Based on: codebase64 base:fpp and base:introduction_to_vertical_tweaks,
;   rewritten
; Limitations: logo resolution is 48 lines (6 screens x 8 charsets), the
;   area must start at the first badline of the frame (VC base = 0) and the
;   colours are per column only (colour RAM row 0). Checked in VICE only.
; =============================================================================
!source "c64.asm"

IRQ_LINE  = $2e
L0        = $33                 ; first FPP line (normal first badline)
N         = 120                 ; FPP lines
M         = N - 1               ; loop iterations (line L0 is set up before)
BLANK     = 47                  ; logo line 47 = glyph row 7 = empty
GFX       = $4000               ; VIC bank 1: 8 charsets, screens in slots 0-5
D018TAB   = $3100               ; logo line (as a $d018 value) per raster line

ptr       = $20                 ; 2 bytes
src       = $22                 ; 2 bytes
lcnt      = $24                 ; logo line 0..47
icnt      = $25                 ; column 0..39
cs        = $26                 ; charset of the line
n0        = $27                 ; screen * 40
acc       = $28                 ; 2 bytes, 8.8 logo line
z         = $2a                 ; zoom step
phase     = $2b
phase2    = $2c
wob       = $2d
tmp       = $2e

        +basic_upstart

start:
        +demo_init nmi
        lda #$7b                ; invalid mode (black) until the first IRQ
        sta VIC_CTRL1
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$02                ; VIC bank 1
        sta CIA2_PRA
        jsr build
        ldx #39                 ; colour RAM row 0 = colours of all FPP lines
-       lda col_tab,x
        sta COLOR_RAM,x
        dex
        bpl -
        jsr make_table
        +set_irq irq, IRQ_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag
        beq main
        lda #0
        sta frame_flag
        inc phase
        lda phase2
        clc
        adc #3
        sta phase2
        jsr make_table
        jmp main

; d018 for each raster line: logo line = acc.hi + wobble, acc += zoom
make_table:
        ldy phase
        lda zoom,y
        sta z
        lda start_lo,y
        sta acc
        lda start_hi,y
        sta acc+1
        lda phase2
        sta wob
        ldx #0
.l:     ldy wob
        lda acc+1
        clc
        adc wobble,y            ; -2..+2 lines: bends the logo
        cmp #BLANK              ; negative (>=$80) or >= 47 -> empty line
        bcc +
        lda #BLANK
+       tay
        lda line_d018,y
        sta D018TAB,x
        lda acc
        clc
        adc z
        sta acc
        bcc +
        inc acc+1
+       lda wob
        clc
        adc #4
        sta wob
        inx
        cpx #N
        bne .l
        rts

; ---- graphics: 6 screens + logo lines in 8 charsets -------------------------
build:
        lda #$33                ; read the char ROM glyphs (IRQs are off)
        sta CPU_PORT
        ldx #63
-       lda text,x
        asl
        asl
        asl
        sta src
        lda #$d0
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

        lda #0                  ; clear $4000-$7fff
        sta ptr
        tay
        ldx #>GFX
-       stx ptr+1
--      sta (ptr),y
        iny
        bne --
        inx
        cpx #$80
        bne -

        lda #0
        sta lcnt
.line:  ldx lcnt
        lda div6,x
        sta cs                  ; charset = glyph row = line / 6
        lda mul40,x
        sta n0                  ; screen (line mod 6) * 40
        lda #0
        sta icnt
.col:   lda n0                  ; n = screen*40 + column, code = n+5 (+10)
        clc
        adc icnt
        cmp #123
        bcc +
        adc #9                  ; carry set: +10, skips codes 128..132
+       adc #5
        sta tmp                 ; char code
        ldx lcnt                ; screen byte (written 8 times, harmless)
        ldy icnt
        lda scr_lo,x
        sta src
        lda scr_hi,x
        sta src+1
        lda tmp
        sta (src),y
        lda tmp                 ; ptr = GFX + cs*$800 + code*8
        asl
        asl
        asl
        sta ptr
        lda tmp
        lsr
        lsr
        lsr
        lsr
        lsr
        sta ptr+1
        lda cs
        asl
        asl
        asl
        clc
        adc ptr+1
        adc #>GFX
        sta ptr+1
        lda #0                  ; pixel byte
        ldx icnt
        cpx #4
        bcc .put
        cpx #36
        bcs .put
        txa
        sec
        sbc #4
        pha
        and #$1c                ; letter*4 -> letter*8 + glyph row
        asl
        ora cs
        tax
        lda glyph,x
        sta tmp
        pla
        and #3                  ; cell: take bits 7-2c, 6-2c
        tax
        lda tmp
-       cpx #0
        beq +
        asl
        asl
        dex
        jmp -
+       rol
        rol
        rol
        and #3
        tax
        lda expand,x
.put:   ldy #0
        sta (ptr),y
        inc icnt
        lda icnt
        cmp #40
        bne .col
        inc lcnt
        lda lcnt
        cmp #48
        beq +
        jmp .line
+       rts

nmi:    rti

; -----------------------------------------------------------------------------
; FPP code, unrolled: one 20-cycle block per raster line. The CPU resumes at
; cycle 55 after each badline halt, runs one block (writes on cycles 1 and 5
; of the next line, before its badline check at cycle 12 and char fetch at
; 15) and halts again on the next opcode fetch at cycle 12.
; -----------------------------------------------------------------------------
irq:    +irq_enter
        lda #$1b                ; normal mode, yscroll 3: line L0 is a badline
        sta VIC_CTRL1
        lda D018TAB             ; logo line for raster line L0
        sta VIC_MEMPTR
        lda #L0
-       cmp VIC_RASTER          ; exits on cycle ~4..11 of line L0
        bne -
        !for i, 1, 6 { nop }    ; first block starts after cycle 12: halts
        !for k, 1, N-1 {
        ldy D018TAB+k           ; 4  logo line of raster line L0+k
        lda #$18 | ((L0+k) & 7) ; 2  yscroll = line & 7 -> forced badline
        sty VIC_MEMPTR          ; 4  write on cycle 1
        sta VIC_CTRL1           ; 4  write on cycle 5
        nop                     ; 6  = 20 cycles: 55..63 + 1..11
        nop
        nop
        }
        lda #$7b                ; halts, then ECM+BMM (black) from next line
        sta VIC_CTRL1
        +set_irq irq, IRQ_LINE
        inc frame_flag
        +irq_exit

frame_flag: !byte 0
glyph:  !fill 64, 0
expand: !byte $00, $0f, $f0, $ff
text:   !for i, 0, 7 { !fill 8, [15, 16, 5, 14, 3, 15, 4, 5][i] }   ; OPENCODE
div6:   !for p, 0, 47 { !byte int(p / 6) }
mul40:  !for p, 0, 47 { !byte (p - 6 * int(p / 6)) * 40 }
scr_lo: !for p, 0, 47 { !byte 0 }
scr_hi: !for p, 0, 47 { !byte >(GFX + $400 * (p - 6 * int(p / 6))) }
line_d018: !for p, 0, 47 { !byte (p - 6 * int(p / 6)) * 16 + int(p / 6) * 2 }
col_tab: !byte 0,0,0,0, 2,2,8,8, 10,10,7,7, 7,7,13,13, 13,13,5,5
         !byte 5,5,3,3, 3,3,14,14, 14,14,4,4, 4,4,10,10, 0,0,0,0
        !align 255, 0
; zoom step (1/256 logo line per raster line): 64 (4x) .. 255 (1x)
zoom:     !for i, 0, 255 { !byte int(160 + 95 * sin(float(i) * 2 * 3.14159265 / 256)) }
; start value centres the logo, plus a slow bounce
start_lo: !for i, 0, 255 { !byte <($1800 - int(160 + 95 * sin(float(i) * 2 * 3.14159265 / 256)) * 60 + int(2000 * sin(float(i) * 6 * 3.14159265 / 256))) }
start_hi: !for i, 0, 255 { !byte >($1800 - int(160 + 95 * sin(float(i) * 2 * 3.14159265 / 256)) * 60 + int(2000 * sin(float(i) * 6 * 3.14159265 / 256))) }
wobble:   !for i, 0, 255 { !byte int(2.5 * sin(float(i) * 2 * 3.14159265 / 256) + 256.5) & $ff }

        * = D018TAB
        !fill N, 0
