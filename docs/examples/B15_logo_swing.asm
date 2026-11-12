; =============================================================================
; B15_logo_swing.asm - B15 Logo swing
; What you see: a big "OPEN / CODE" logo whose rows sway left and right in a wave.
; How:
; - the logo (16 char rows x 32 cols of $a0 blocks) is built at start from
;   the char ROM, 1 font pixel = 1 char
; - per row: offset = swing[t + row*8] (0..63 px) -> coarse = offset/8 chars
;   (row copied to the screen at that column), fine = offset&7 -> $d016
; - a raster IRQ polls $d012 and writes each row's $d016 on the last raster
;   line of the row above, delayed to the right border, so the change lands
;   outside the visible text area (no stable raster needed)
; Docs: docs/08-effects-library.md (B15)
; Based on: codebase64 base:logo_swing, rewritten
; Limitations: the $d016 write has ~7 cycles of jitter; on real hardware a
;   few pixels at the right end of a row's last line may flicker.
; =============================================================================
!source "c64.asm"

LOGO      = $3000               ; 16 rows x 32 bytes, built at start
LOGO_ROW  = 4                   ; first screen row of the logo
ROWS      = 16
SWING_IRQ = $32 + LOGO_ROW*8 - 3 ; a few lines before the first write

zp_src  = $20                   ; 2 bytes
zp_dst  = $22                   ; 2 bytes
zp_t    = $24
zp_row  = $25
zp_bits = $26

        +basic_upstart

start:
        +demo_init nmi
        jsr build_logo          ; reads the char ROM: IRQs must be off
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$15                ; ROM font: $a0 = solid block
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        lda #$20
        +fill_1000 SCREEN
        ldx #0                  ; colour per logo row (gradient)
-       lda row_lo,x
        sta zp_dst
        lda row_hi,x
        eor #>(SCREEN xor COLOR_RAM) ; $04xx -> $d8xx
        sta zp_dst+1
        lda logo_col,x
        ldy #39
--      sta (zp_dst),y
        dey
        bpl --
        inx
        cpx #ROWS
        bne -
        +set_irq irq_swing, SWING_IRQ
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *

; ---- logo rows: poll each row's last raster line, then write $d016 ----------
irq_swing:
        +irq_enter
        ldx #0
.row:   lda fine,x
        ldy line_tab,x
-       cpy VIC_RASTER          ; wait for the last line of the row above
        bne -
        ldy #9                  ; $d012 read at cycle 0..6, then 2+2+44+2+2
--      dey                     ; cycles -> the write (last cycle of sta)
        bne --                  ; lands at cycle ~56..62: right border
        nop
        nop
        sta VIC_CTRL2
        inx
        cpx #ROWS
        bne .row
        +set_irq irq_bottom, $fc
        +irq_exit

; ---- below the screen: reset $d016, compute and copy the next frame -----------
irq_bottom:
        +irq_enter
        lda #$c8
        sta VIC_CTRL2
        jsr update
        +set_irq irq_swing, SWING_IRQ
        +irq_exit

update:
        inc zp_t
        inc zp_t
        ldx #ROWS-1
.r:     txa                     ; swing index = t + row*8
        asl
        asl
        asl
        clc
        adc zp_t
        tay
        lda swing,y
        pha
        and #7
        ora #$c8                ; 40 columns + fine scroll
        sta fine,x
        pla
        lsr
        lsr
        lsr                     ; coarse = 0..7 chars
        cmp coarse,x
        beq .next               ; same column as last frame: no copy
        sta coarse,x
        ; screen[col] = padded[8 - coarse + col], col = 0..39
        eor #$ff
        sec
        adc #8                  ; 8 - coarse
        clc
        adc logo_lo,x
        sta .src+1
        lda logo_hi,x
        adc #0
        sta .src+2
        lda row_lo,x
        sta .dst+1
        lda row_hi,x
        sta .dst+2
        ldy #39
.src:   lda $ffff,y             ; self-modified
.dst:   sta $ffff,y             ; self-modified
        dey
        bpl .src
.next:  dex
        bpl .r
        rts

; ---- build the padded logo from the char ROM ("OPEN" over "CODE") ---------
; each logo row is 48 bytes: 8 spaces, 32 logo cells, 8 spaces
build_logo:
        lda #$20
        ldx #0
-       sta LOGO,x
        sta LOGO+$100,x
        sta LOGO+$200,x
        inx
        bne -
        lda #$33                ; char ROM at $d000
        sta CPU_PORT
        ldx #0                  ; letter 0..7
.l:     lda let_lo,x
        sta zp_dst
        lda let_hi,x
        sta zp_dst+1
        lda letters,x           ; ROM address = $d000 + code*8
        asl
        asl
        asl
        sta zp_src
        lda #$d0
        adc #0
        sta zp_src+1
        stx zp_row
        ldy #0                  ; font row
.fy:    lda (zp_src),y
        sta zp_bits
        sty zp_t
        ldy #0
-       asl zp_bits             ; 1 font pixel -> 1 char
        lda #$20
        bcc +
        lda #$a0
+       sta (zp_dst),y
        iny
        cpy #8
        bne -
        lda zp_dst              ; next logo row (+48)
        clc
        adc #48
        sta zp_dst
        bcc +
        inc zp_dst+1
+       ldy zp_t
        iny
        cpy #8
        bne .fy
        ldx zp_row
        inx
        cpx #8
        bne .l
        lda #BANK_IO_ONLY
        sta CPU_PORT
        lda #0
        sta zp_t
        rts

nmi:    rti

letters: !scr "OPENCODE"
let_lo: !for l, 0, 7 { !byte <(LOGO + (l >> 2)*8*48 + 8 + (l & 3)*8) }
let_hi: !for l, 0, 7 { !byte >(LOGO + (l >> 2)*8*48 + 8 + (l & 3)*8) }
line_tab: !for r, 0, ROWS-1 { !byte $32 + (LOGO_ROW + r)*8 - 1 }
row_lo: !for r, 0, ROWS-1 { !byte <(SCREEN + (LOGO_ROW + r)*40) }
row_hi: !for r, 0, ROWS-1 { !byte >(SCREEN + (LOGO_ROW + r)*40) }
logo_lo: !for r, 0, ROWS-1 { !byte <(LOGO + r*48) }
logo_hi: !for r, 0, ROWS-1 { !byte >(LOGO + r*48) }
logo_col: !byte 6, 14, 3, 13, 1, 13, 3, 14, 2, 8, 10, 7, 1, 7, 10, 8
fine:   !fill ROWS, $c8
coarse: !fill ROWS, $ff         ; $ff = force a copy on the first frame

        !align 255, 0
swing:  !for i, 0, 255 { !byte int(32 + 31.5 * sin(float(i) * 2 * 3.14159265 / 256)) }
