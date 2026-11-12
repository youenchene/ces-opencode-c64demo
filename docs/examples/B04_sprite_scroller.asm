; =============================================================================
; B04_sprite_scroller.asm - B4 Sprite scroller
; What you see: a 16-pixel-high scroller made of sprites, running through the
;   (opened) lower border, under a normal text screen.
; How:
; - 8 x/y-expanded sprites side by side form a 192x8 bit strip (8 rows of
;   24 bytes); each frame every row is ROLed one bit to the left, through
;   all 24 bytes (unrolled with !for), and the next font bit enters at the
;   right end. After 8 bits the next letter's 8 font bytes are loaded
; - sprites are not limited by the char grid: here they sit at Y = $fe,
;   in the bottom border, opened with the B17 trick (24 rows at line $f9)
; Docs: docs/08-effects-library.md (B4, B17)
; Based on: codebase64 base:scrolltext_using_sprites, rewritten
; Limitations: the side borders are closed, so the strip is cut at the
;   screen edges (opening them is C1).
; =============================================================================
!source "c64.asm"

SPRITES  = $2000                ; 8 blocks, pointers $80-$87 (rows 0-7 used)
FONT     = $3000                ; RAM copy of ROM chars 0..63
SPR_Y    = $fe                  ; first line of the strip (lower border)
OPEN_IRQ = $f9                  ; 24 rows here -> bottom border stays open
TOP_IRQ  = $14                  ; next frame, top border: 25 rows + roll

zp_text = $20                   ; 2 bytes
zp_bit  = $22                   ; bits left in the current letter
cur     = $28                   ; 8 bytes: font rows being shifted out

        +basic_upstart

start:
        +demo_init nmi
        lda #$33                ; copy ROM chars 0..63 (char ROM at $d000)
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
        lda #0                  ; empty sprites, empty idle byte
        sta $3fff
        tax
-       sta SPRITES,x
        sta SPRITES+$100,x
        inx
        bne -
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM
        ldx #39
-       lda title,x
        sta SCREEN+10*40,x
        lda info,x
        sta SCREEN+12*40,x
        dex
        bpl -
        ldx #7                  ; sprites side by side, 48 pixels apart
-       txa
        ora #SPRITES/64
        sta SCREEN+$3f8,x
        lda #YELLOW
        sta SPR0_COLOR,x
        txa
        asl
        tay
        lda spr_x,x
        sta SPR0_X,y
        lda #SPR_Y
        sta SPR0_Y,y
        dex
        bpl -
        lda #$e0                ; sprites 5, 6, 7: X > 255
        sta SPR_X_MSB
        lda #$ff
        sta SPR_EXPAND_X
        sta SPR_EXPAND_Y
        sta SPR_ENABLE
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        jsr next_letter
        lda #$17                ; screen $0400, ROM lowercase
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_open, OPEN_IRQ
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *

; ---- line $f9: 24 rows -> the lower border is never switched on ------------
irq_open:
        +irq_enter
        lda #$13
        sta VIC_CTRL1
        +set_irq irq_top, TOP_IRQ
        +irq_exit

; ---- top border of the next frame: 25 rows again, scroll the strip ---------
irq_top:
        +irq_enter
        lda #$1b
        sta VIC_CTRL1
        jsr roll
        dec zp_bit
        bne +
        jsr next_letter
+       +set_irq irq_open, OPEN_IRQ
        +irq_exit

; every sprite row: font bit -> carry -> 24 bytes, right to left
; byte b of sprite s, row r = SPRITES + s*64 + r*3 + b
roll:
        !for r, 0, 7 {
        asl cur+r
        !for s, 0, 7 {
        !for b, 0, 2 {
        rol SPRITES + (7-s)*64 + r*3 + (2-b)
        }
        }
        }
        rts

next_letter:
        ldy #0
        lda (zp_text),y
        bne +                   ; 0 = end of text -> wrap
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        lda (zp_text),y
+       asl                     ; letter*8 (letter < 64)
        asl
        asl
        tax
        ldy #0
        bcs .hi                 ; letters 32..63 are in the second page
-       lda FONT,x
        sta cur,y
        inx
        iny
        cpy #8
        bne -
        beq .next
.hi:
-       lda FONT+$100,x
        sta cur,y
        inx
        iny
        cpy #8
        bne -
.next:  lda #8
        sta zp_bit
        inc zp_text
        bne +
        inc zp_text+1
+       rts

nmi:    rti

spr_x:  !for i, 0, 7 { !byte <(24 + i*48) }   ; 9th bit set in $d010 = $e0
title:  !scr "        B4: sprite scroller             "
info:   !scr "   look down: it runs in the border!    "
scroll_text:                    ; lowercase only (codes < 64), 0 = end
        !scr "this scroller is made of 8 expanded sprites, roled one "
        !scr "bit per frame ... codeurs en seine 2026 ...      "
        !byte 0
