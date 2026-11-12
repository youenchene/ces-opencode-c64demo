; =============================================================================
; C06_fli.asm - C6 FLI (Flexible Line Interpretation) picture
; What you see: a full-screen multicolour bitmap of diagonal rainbow stripes
;   where EVERY pixel line of every 4x8 cell has its own 2 colours (normal
;   multicolour bitmap: same colours for the 8 lines of a cell). The %00
;   background pixels cycle through colours. The 3 leftmost columns show
;   the classic "FLI bug" (grey).
; Technique:
;   - VIC bank 1: 8 screens at $4000-$5fff, bitmap at $6000
;   - on every raster line L ($30-$f7): $d018 selects screen L&7, then
;     $d011 yscroll = L&7 is written on cycle 15: a badline starts after the
;     cycle-14 row-counter reset, so RC keeps counting 0..7 (bitmap lines)
;     while the VIC re-fetches 40 colour bytes from the new screen
;   - the badline halts the CPU until cycle 55 on every line, so unrolled
;     24-cycle blocks re-sync themselves (no stable raster needed)
;   - the c-accesses for the first 3 columns happen before the VIC owns the
;     bus: it reads $ff -> FLI bug (light grey) on the left
;   - picture generated at start-up (no 17 KB file to load)
; Docs: docs/08-effects-library.md (C6)
; Based on: codebase64 base:fli and base:fli_displayer, rewritten
; Limitations: generated pattern, not a converted picture (a real FLI
;   picture = 8 KB bitmap + 8 KB screens + 1 KB colour RAM in the same
;   layout). Colour RAM (%11 pixels) is per cell only. The FLI loop takes
;   200 lines of CPU time. Checked in VICE only.
; =============================================================================
!source "c64.asm"

IRQ_LINE  = $2e
L0        = $30                 ; first FLI line (normal badline, yscroll 0)
NL        = 200                 ; lines $30..$f7
!ifndef DLY { DLY = 12 }        ; cycles 63..11 -> $d011 write on cycle 15
SCREENS   = $4000               ; 8 x $400
BITMAP    = $6000
PIXELS    = %01101100           ; pixel pairs: screen hi, screen lo, colram, bg

ptr       = $20                 ; 2 bytes
s         = $22                 ; screen 0..7
r         = $23                 ; char row 0..24
c         = $24                 ; column 0..39
y         = $25                 ; pixel line r*8+s
frame     = $26

; delay of .n cycles (.n = 2..255), clobbers nothing but flags
!macro delay .n {
        !set .r = .n
        !if .r & 1 { bit $ea : !set .r = .r - 3 }
        !for .i, 1, .r / 2 { nop }
}

        +basic_upstart

start:
        +demo_init nmi
        lda #$0b                ; display off while building
        sta VIC_CTRL1
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        jsr build
        lda #$02                ; VIC bank 1 ($4000-$7fff)
        sta CIA2_PRA
        lda #$08                ; screen 0, bitmap at +$2000
        sta VIC_MEMPTR
        lda #$d8                ; multicolour, 40 columns
        sta VIC_CTRL2
        lda #$38                ; bitmap, display on, yscroll 0
        sta VIC_CTRL1
        +set_irq irq, IRQ_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
-       jmp -                   ; everything happens in the IRQ

; ---- picture: bitmap pattern + 8 screens + colour RAM ------------------------
build:  lda #<BITMAP
        sta ptr
        lda #>BITMAP
        sta ptr+1
        ldx #$20                ; 32 pages = 8 KB
        ldy #0
        lda #PIXELS
-       sta (ptr),y
        iny
        bne -
        inc ptr+1
        dex
        bne -

        ldx #0                  ; colour RAM: one colour per char row
-       txa
        and #15
        tay
        lda rainbow,y
        sta COLOR_RAM,x
        sta COLOR_RAM+$100,x
        sta COLOR_RAM+$200,x
        sta COLOR_RAM+$2e8,x
        inx
        bne -

        lda #0
        sta s
.s:     lda s                   ; ptr = SCREENS + s*$400
        asl
        asl
        clc
        adc #>SCREENS
        sta ptr+1
        lda #0
        sta ptr
        sta r
.r:     lda r
        asl
        asl
        asl
        ora s
        sta y                   ; pixel line of this (row, screen)
        ldy #0
.c:     tya                     ; hi nibble: rainbow[(c + y) & 15]
        clc
        adc y
        and #15
        tax
        lda rainbow,x
        asl
        asl
        asl
        asl
        sta c
        tya                     ; lo nibble: rainbow[(c*2 - y) & 15]
        asl
        sec
        sbc y
        and #15
        tax
        lda rainbow,x
        ora c
        sta (ptr),y
        iny
        cpy #40
        bne .c
        lda ptr                 ; next row: +40
        clc
        adc #40
        sta ptr
        bcc +
        inc ptr+1
+       inc r
        lda r
        cmp #25
        bne .r
        inc s
        lda s
        cmp #8
        bne .s
        rts

nmi:    rti

; -----------------------------------------------------------------------------
; FLI display: one unrolled block per raster line. Each block's first opcode
; fetch is halted by the previous badline until cycle 55, then:
;   55-56 lda #  57-60 sta $d018 (write 60)  61-62 lda #
;   delay DLY (63..11)  12-15 sta $d011 (write 15)  -> badline from cycle 15
; -----------------------------------------------------------------------------
irq:    +irq_enter
        lda #$38 | (L0 & 7)     ; line L0: normal badline (RC = 0)
        sta VIC_CTRL1
        lda #$08
        sta VIC_MEMPTR
        lda #L0
-       cmp VIC_RASTER          ; exits on cycle ~4..11 of line L0
        bne -
        !for i, 1, 6 { nop }    ; past cycle 12: the next fetch is halted
        !for l, L0+1, L0+NL-1 {
        lda #((l & 7) << 4) | $08 ; 2  screen l&7, bitmap $6000
        sta VIC_MEMPTR          ; 4
        lda #$38 | (l & 7)      ; 2
        +delay DLY
        sta VIC_CTRL1           ; 4  write on cycle 15 of line l
        }
        lda #$3b                ; after $f7: no more badlines, safe value
        sta VIC_CTRL1
        lda #$08
        sta VIC_MEMPTR
        inc frame               ; background (%00 pixels) cycles slowly
        lda frame
        lsr
        lsr
        lsr
        and #15
        tax
        lda rainbow,x
        sta BACKGROUND
        +set_irq irq, IRQ_LINE
        +irq_exit

rainbow: !byte 2, 8, 10, 7, 13, 5, 3, 14, 6, 4, 11, 12, 15, 1, 9, 0
