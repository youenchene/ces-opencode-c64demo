; =============================================================================
; C09_disco_floor.asm - C9 Perspective "disco floor" scroller
; What you see: a floor of coloured tiles in perspective on the lower half of
; the screen; white letters scroll right-to-left across the tiles while the
; colour pattern under them flows left-to-right.
; How:
; - a multicolour bitmap (generated at assemble time) draws the floor: 7 tile
;   rows x 20 tile columns, columns converging to a vanishing point. Pixels of
;   even columns use MC code 01 (screen RAM high nibble), odd columns code 10
;   (low nibble), the first line of each tile row is black (code 00)
; - so any char holds at most one even and one odd tile: writing one screen
;   byte per char recolours whole tiles; per-char tables (assemble time) say
;   which even/odd tile each char shows. 520 chars are rewritten per step
;   with a 26-cycle loop, racing ahead of the beam
; - scroll trick: alternately (1) $d016 = 7 and the letters move one tile
;   left, (2) $d016 = 0 and the pattern moves one tile right. On the nearest
;   row (16 px tiles) both seem to glide by ~8 px per step
; - letters come from the ROM font (copied at start with $01=$33), 7 lines
; Docs: docs/08-effects-library.md (C9)
; Based on: codebase64 base:discofloor_scroller_as_being_used_in_aechzzeit
;           by Bitbreaker, rewritten (no FLI: tile rows are char-aligned)
; Limitations: tile rows are aligned to char rows instead of FLI splits, so
; rows can't be any height; far tiles are 4 px wide, where a slanted edge
; crosses a char a tile may borrow its neighbour's colour; no sprites.
; =============================================================================
!source "c64.asm"

FR0     = 12                    ; first char row of the floor
NCR     = 13                    ; char rows of the floor (12..24)
NROWS   = 7                     ; tile rows (= font lines 0..6)
NCOLS   = 20
NCELLS  = NROWS * NCOLS         ; 140, index 140 = "no tile" (black)
BITMAP  = $2000
FONT    = $c000                 ; ROM font copy (64 chars, 512 bytes)
SCR_FLOOR = SCREEN + FR0 * 40

zp_ph   = $20                   ; step phase (0 letters / 1 pattern)
zp_txt  = $21                   ; 2 bytes, text pointer
zp_bit  = $23                   ; font column 0..7 in the current letter
zp_cp   = $24                   ; pattern counter
zp_fr   = $25                   ; frame counter
zp_d016 = $26

        +basic_upstart

start:
        +demo_init nmi
        lda #$33                ; char ROM visible at $d000 (IRQs are off)
        sta CPU_PORT
        ldx #0
-       lda $d000,x
        sta FONT,x
        lda $d100,x
        sta FONT+$100,x
        inx
        bne -
        lda #BANK_IO_ONLY
        sta CPU_PORT

        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #0
        +fill_1000 SCREEN
        lda #0
        +fill_1000 COLOR_RAM
        lda #$3b                ; bitmap mode
        sta VIC_CTRL1
        lda #$18                ; screen $0400, bitmap $2000
        sta VIC_MEMPTR
        lda #$10
        sta zp_d016
        sta VIC_CTRL2
        lda #<text
        sta zp_txt
        lda #>text
        sta zp_txt+1
        ldx #NCELLS             ; clear the tile buffers
        lda #0
-       sta letters,x
        sta pattern,x
        sta cellcol,x
        sta cellhi,x
        dex
        cpx #$ff
        bne -
        sta zp_bit
        sta zp_ph
        sta zp_cp
        +set_irq irq, $fc
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag
        beq main
        lda #0
        sta frame_flag
        inc zp_fr
        lda zp_fr
        and #3                  ; one step every 4 frames
        bne main
        lda zp_ph
        eor #1
        sta zp_ph
        beq +
        lda #$17                ; MC, 38 columns, xscroll 7
        sta VIC_CTRL2
        jsr shift_letters
        jmp ++
+       lda #$10                ; xscroll 0
        sta VIC_CTRL2
        jsr shift_pattern
++      jsr combine
        jsr update_screen
        jmp main

irq:    +irq_enter
        inc frame_flag
        +irq_exit

; ---- letters: shift left, new column from the font on the right -------------
shift_letters:
        ldx #0
-       lda letters+1,x
        sta letters,x
        inx
        cpx #NCELLS-1
        bne -
        ldy #0
        lda (zp_txt),y
        bne +
        lda #<text
        sta zp_txt
        lda #>text
        sta zp_txt+1
        lda (zp_txt),y
+       asl                     ; font address = FONT + code*8
        asl
        asl
        sta .src+1
        lda (zp_txt),y          ; high byte = code >> 5 (codes 0..63)
        lsr
        lsr
        lsr
        lsr
        lsr
        clc
        adc #>FONT
        sta .src+2
        ldx zp_bit
        lda bitmask,x
        sta .mask+1
        ldx #0                  ; font line = tile row
        ldy #NCOLS-1
.row:
.src:   lda FONT,x
.mask:  and #$80
        beq +
        lda #WHITE
+       sta letters,y
        tya
        clc
        adc #NCOLS
        tay
        inx
        cpx #NROWS
        bne .row
        inc zp_bit
        lda zp_bit
        cmp #8
        bne +
        lda #0
        sta zp_bit
        inc zp_txt
        bne +
        inc zp_txt+1
+       rts

; ---- pattern: shift right, new column on the left ------------------------------
shift_pattern:
        ldx #NCELLS-1
-       lda pattern-1,x
        sta pattern,x
        dex
        bne -
        inc zp_cp
        ldy #0
        ldx #0
-       txa
        clc
        adc zp_cp
        and #15
        tax
        lda patcol,x
        sta pattern,y
        txa                     ; restore row counter
        sec
        sbc zp_cp
        and #15
        tax
        tya
        clc
        adc #NCOLS
        tay
        inx
        cpx #NROWS
        bne -
        rts

; ---- tile colour = letter if set, else pattern; also high-nibble copy -----------
combine:
        ldx #NCELLS-1
-       lda letters,x
        bne +
        lda pattern,x
+       sta cellcol,x
        asl
        asl
        asl
        asl
        sta cellhi,x
        dex
        cpx #$ff                ; X starts >= 128: bpl would stop at once
        bne -
        rts

; ---- 520 screen bytes = (even tile << 4) | odd tile -----------------------------
!macro upd .base, .count {
        ldx #0
-       ldy evtab+.base,x       ; 4
        lda cellhi,y            ; 4
        ldy odtab+.base,x       ; 4
        ora cellcol,y           ; 4
        sta SCR_FLOOR+.base,x   ; 5
        inx                     ; 2
        !if .count < 256 { cpx #.count }
        bne -                   ; 3
}
update_screen:
        +upd 0, 256
        +upd 256, 256
        +upd 512, NCR*40-512
        rts

nmi:    rti
frame_flag: !byte 0
bitmask: !byte $80, $40, $20, $10, $08, $04, $02, $01
patcol: !byte 6, 4, 14, 3, 13, 7, 10, 8, 2, 4, 6, 11, 5, 3, 14, 6
text:   !scr "   codeurs en seine 2026 ... opencode on a c64 ... disco floor!   "
        !byte 0

        !align 255, 0
letters: !fill NCELLS + 1, 0
pattern: !fill NCELLS + 1, 0
cellcol: !fill NCELLS + 1, 0    ; [140] stays 0 = black ("no tile")
cellhi:  !fill NCELLS + 1, 0

; ---- assemble-time geometry -------------------------------------------------
; tile width in MC pixels grows linearly from 4 (far) to 8 (near): perspective
!macro colat .x, .y {           ; -> ccol = tile column or -1
        !set .w = 4.0 + 4.0 * float(.y) / (NCR * 8 - 1)
        !set .f = (float(.x) - 80.0) / .w + NCOLS / 2
        !if .f < 0 { !set ccol = -1 } else {
                !set ccol = int(.f)
                !if ccol >= NCOLS { !set ccol = -1 }
        }
}
!macro rowof .crr {             ; -> trow = tile row, tfirst = 1 on its top
        !set trow = 6
        !set tfirst = 0
        !if .crr < 10 { !set trow = 5 }
        !if .crr < 7 { !set trow = 4 }
        !if .crr < 5 { !set trow = 3 }
        !if .crr < 3 { !set trow = 2 }
        !if .crr < 2 { !set trow = 1 }
        !if .crr < 1 { !set trow = 0 }
        !if .crr = 0 | .crr = 1 | .crr = 2 | .crr = 3 | .crr = 5 | .crr = 7 | .crr = 10 { !set tfirst = 1 }
}
evtab:
!for crr, 0, NCR - 1 {
        +rowof crr
        !for cc, 0, 39 {
                !set ev = NCELLS
                !for p, 0, 3 {
                        +colat cc * 4 + p, crr * 8 + 4
                        !if ccol >= 0 { !if (ccol & 1) = 0 { !set ev = trow * NCOLS + ccol } }
                }
                !byte ev
        }
}
odtab:
!for crr, 0, NCR - 1 {
        +rowof crr
        !for cc, 0, 39 {
                !set od = NCELLS
                !for p, 0, 3 {
                        +colat cc * 4 + p, crr * 8 + 4
                        !if ccol >= 0 { !if (ccol & 1) = 1 { !set od = trow * NCOLS + ccol } }
                }
                !byte od
        }
}

        * = BITMAP + FR0 * 320
!for crr, 0, NCR - 1 {
        +rowof crr
        !for cc, 0, 39 {
                !for l, 0, 7 {
                        !set b = 0
                        !if (tfirst = 0) | (l > 0) {
                                !for p, 0, 3 {
                                        +colat cc * 4 + p, crr * 8 + l
                                        !if ccol >= 0 {
                                                !set b = b | ((1 + (ccol & 1)) << (6 - 2 * p))
                                        }
                                }
                        }
                        !byte b
                }
        }
}
