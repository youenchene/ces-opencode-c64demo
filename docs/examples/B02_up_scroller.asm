; =============================================================================
; B02_up_scroller.asm - B2 Up-scroller (credits roll)
; What you see: centred credit lines rolling up the screen, one pixel per
;   frame, fading in at the bottom and out at the top.
; How:
; - $d011 YSCROLL counts 7 -> 0 (24-row mode hides the rows at the edges)
; - two screens (double buffer, $2000 and $2400): while one is shown, the
;   other gets a copy shifted up one row + the next text line at the bottom
; - when YSCROLL wraps, $d018 flips to the prepared screen and YSCROLL = 7
;   in the same vblank IRQ: no tearing, and the copy has 8 frames to finish
; - colour RAM is fixed per row (dark-grey-white gradient) = the fade
; Docs: docs/08-effects-library.md (B2)
; Based on: codebase64 base:1x1_upscroll, rewritten
; =============================================================================
!source "c64.asm"

SCREEN_A = $2000                ; $d018 = $86 (screen $2000, ROM lowercase $1800)
SCREEN_B = $2400                ; $d018 = $96
BOTTOM   = $fc                  ; vblank IRQ line

zp_text = $20                   ; 2 bytes: next credit line
zp_y    = $22                   ; YSCROLL 0..7
zp_buf  = $23                   ; 0 = A shown, 1 = B shown
zp_copy = $24                   ; 1 = back buffer must be prepared
zp_len  = $25

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN_A
        +fill_1000 SCREEN_B
        ldx #24                 ; colour per row: the fade at both ends
-       lda row_col,x
        ldy row_lo,x
        sty .col+1
        ldy row_hi,x
        sty .col+2
        ldy #39
.col:   sta $ffff,y             ; self-modified: colour RAM row
        dey
        bpl .col
        dex
        bpl -
        lda #<credits
        sta zp_text
        lda #>credits
        sta zp_text+1
        lda #7
        sta zp_y
        lda #0
        sta zp_buf
        lda #1
        sta zp_copy
        lda #$86
        sta VIC_MEMPTR
        lda #$17                ; DEN, 24 rows, YSCROLL 7
        sta VIC_CTRL1
        +set_irq irq_bottom, BOTTOM
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda zp_copy             ; prepare the hidden screen when asked
        beq main
        lda zp_buf
        bne +
        jsr copy_a_to_b         ; A shown -> prepare B
        lda #<(SCREEN_B+24*40)
        ldx #>(SCREEN_B+24*40)
        bne ++
+       jsr copy_b_to_a
        lda #<(SCREEN_A+24*40)
        ldx #>(SCREEN_A+24*40)
++      jsr new_line
        lda #0
        sta zp_copy
        jmp main

; ---- vblank: scroll 1 pixel, flip screens when YSCROLL wraps ---------------
irq_bottom:
        +irq_enter
        dec zp_y
        bpl .set
        lda zp_copy             ; back buffer not ready yet? wait a frame
        beq +
        inc zp_y
        bpl .set
+       lda #7
        sta zp_y
        lda zp_buf
        eor #1
        sta zp_buf
        tax
        lda d018_tab,x
        sta VIC_MEMPTR
        lda #1
        sta zp_copy
.set:   lda zp_y
        ora #$10                ; DEN on, bit 3 = 0: 24 rows
        sta VIC_CTRL1
        +set_irq irq_bottom, BOTTOM
        +irq_exit

; ---- back = front rows 1..24 moved up one row (960 bytes) -------------------
!macro copy_up .from, .to {
        ldx #0
-       !for k, 0, 3 {
        lda .from+40+k*240,x
        sta .to+k*240,x
        }
        inx
        cpx #240
        bne -
        rts
}
copy_a_to_b: +copy_up SCREEN_A, SCREEN_B
copy_b_to_a: +copy_up SCREEN_B, SCREEN_A

; ---- write the next credit line, centred, at A/X (row 24 of back screen) ----
new_line:
        sta .dst+1
        stx .dst+2
        lda #$20
        ldx #39
-       jsr .put
        dex
        bpl -
        ldy #0                  ; measure the line ($ff ends it)
-       lda (zp_text),y
        cmp #$ff
        beq +
        iny
        bne -
+       sty zp_len
        lda #40                 ; first column = (40 - len) / 2
        sec
        sbc zp_len
        lsr
        tax
        ldy #0
-       cpy zp_len
        beq +
        lda (zp_text),y
        jsr .put
        inx
        iny
        bne -
+       iny                     ; skip the $ff
        tya
        clc
        adc zp_text
        sta zp_text
        bcc +
        inc zp_text+1
+       ldy #0
        lda (zp_text),y
        cmp #$fe                ; $fe = end of credits -> start again
        bne +
        lda #<credits
        sta zp_text
        lda #>credits
        sta zp_text+1
+       rts
.put:
.dst:   sta $ffff,x             ; self-modified
        rts

nmi:    rti

d018_tab: !byte $86, $96
row_lo:  !for r, 0, 24 { !byte <(COLOR_RAM + r*40) }
row_hi:  !for r, 0, 24 { !byte >(COLOR_RAM + r*40) }
row_col: !byte 0, 11, 12, 15, 1, 1, 1, 1, 1, 1, 1, 1, 1
         !byte 1, 1, 1, 1, 1, 1, 1, 1, 15, 12, 11, 0

; one line per entry, $ff ends a line, $fe ends the credits
credits:
        !scr "B2: credits roll", $ff
        !scr "", $ff
        !scr "opencode", $ff
        !scr "at Codeurs en Seine 2026", $ff
        !scr "Rouen, Kindarena", $ff
        !scr "", $ff
        !scr "code", $ff
        !scr "an AI agent + a human", $ff
        !scr "", $ff
        !scr "technique", $ff
        !scr "$d011 yscroll + double buffer", $ff
        !scr "", $ff
        !scr "greetings to all sceners", $ff
        !scr "", $ff, "", $ff, "", $ff, "", $ff
        !byte $fe
