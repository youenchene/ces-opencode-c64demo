; =============================================================================
; B18_raster_split.asm - B18 Raster split curtains
; What you see: 6 coloured background bands behind text, edges sliding up and
; down by whole rows, colours cycling.
; How:
; - one raster IRQ per split, chained: each handler writes $d021 and sets
;   $d012 to the next split line (table rebuilt every frame)
; - a split is always on the LAST raster line of the row above (never a
;   badline), and a short delay moves the write into the right border, so
;   the edge is clean without a stable raster
; - split row k = k*4 + sine(t + k*24) (0..3): the bands never cross
; Docs: docs/08-effects-library.md (B18)
; Based on: codebase64 base:horizontal_raster_split, rewritten
; Limitations: band edges move by whole char rows only.
; =============================================================================
!source "c64.asm"

SPLITS = 5                      ; 5 splits -> 6 bands
BOTTOM = $fc

zp_k    = $20                   ; next split index
zp_t    = $21                   ; frame counter

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        lda #$17                ; ROM font, mixed case
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        lda #$20
        +fill_1000 SCREEN
        lda #BLACK              ; black text on the coloured bands
        +fill_1000 COLOR_RAM
        ldx #0                  ; the same line of text on every other row
-       lda text,x
        !for r, 0, 12 { sta SCREEN + (r*2)*40, x }
        inx
        cpx #40
        bne -
        jsr update

        +set_irq irq_bottom, BOTTOM
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *                   ; 3-cycle loop: IRQ entry jitter 0..2 cycles

; ---- one handler for all splits ------------------------------------------------
irq_split:
        +irq_enter              ; IRQ at cycle ~0 + 7 + 0..2 + 13
        ldx zp_k
        lda band_col+1,x
        ldy #5                  ; delay: the write lands at cycle ~58-60,
-       dey                     ; in the right border of the row's last line
        bne -
        sta BACKGROUND
        inx
        stx zp_k
        cpx #SPLITS
        beq +
        lda split_line,x
        sta VIC_RASTER
        +irq_exit
+       +set_irq irq_bottom, BOTTOM
        +irq_exit

; ---- below the screen: top band colour, next frame's splits ---------------------
irq_bottom:
        +irq_enter
        jsr update
        lda band_col
        sta BACKGROUND
        lda #0
        sta zp_k
        +set_irq irq_split, 0   ; line set just below
        lda split_line
        sta VIC_RASTER
        +irq_exit

update:
        inc zp_t
        ldx #0                  ; split lines
-       txa                     ; sine index = t + k*24
        asl
        asl
        asl
        sta split_line,x        ; temp: k*8
        asl
        adc split_line,x        ; k*24
        adc zp_t
        tay
        lda step,y              ; 0..3
        clc
        adc row_base,x          ; row = (k+1)*4 + 0..3
        asl
        asl
        asl
        adc #$32                ; last raster line of the row above
        sta split_line,x
        inx
        cpx #SPLITS
        bne -
        lda zp_t                ; band colours: palette shifted every 16 frames
        lsr
        lsr
        lsr
        lsr
        sta zp_k
        ldx #SPLITS
-       txa
        clc
        adc zp_k
        and #7
        tay
        lda palette,y
        sta band_col,x
        dex
        bpl -
        rts

nmi:    rti

row_base: !for k, 1, SPLITS { !byte k*4 }
palette: !byte LIGHT_GREY, YELLOW, LIGHT_GREEN, CYAN, LIGHT_BLUE, LIGHT_RED, GREY, ORANGE
text:   !scr "   raster split: $d021 changes between  "
split_line: !fill SPLITS, 0
band_col: !fill SPLITS+1, 0

        !align 255, 0
step:   !for i, 0, 255 { !byte int(2 + 1.99 * sin(float(i) * 2 * 3.14159265 / 256)) }
