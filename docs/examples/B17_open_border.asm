; =============================================================================
; B17_open_border.asm - B17 Open top/bottom border
; What you see: "OPEN" waving in the top border, "CODE" in the bottom border.
; How:
; - the VIC turns the vertical border on when it reaches line 251 in 25-row
;   mode (line 247 in 24-row mode)
; - at line $f9 we switch to 24 rows ($d011 bit 3 = 0): line 247 is already
;   past and line 251 no longer matches, so the border stays open until the
;   next frame. 25 rows are set again mid-screen (line $40)
; - the open area shows $d021 plus the idle byte $3fff (set to 0), and sprites
; - 8 x/y-expanded sprites hold letters copied from the char ROM
; Docs: docs/08-effects-library.md (B17)
; Based on: codebase64 base:removing_the_top_bottom_border, rewritten
; =============================================================================
!source "c64.asm"

SPRITES  = $2000                ; 8 sprite blocks (pointer $80-$87)
OPEN_IRQ = $f9                  ; between line 247 and 251
MID_IRQ  = $40                  ; top sprites done, bottom ones not started

zp_t    = $20
zp_src  = $21                   ; 2 bytes
zp_dst  = $23                   ; 2 bytes

        +basic_upstart

start:
        +demo_init nmi
        jsr make_sprites        ; reads the char ROM: IRQs must be off
        lda #BLACK
        sta BORDER
        sta $3fff               ; idle graphics in the open border: empty
        lda #BLUE               ; open border shows $d021: blue = proof
        sta BACKGROUND
        lda #$17
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM
        ldx #39
-       lda text,x
        sta SCREEN+12*40,x
        dex
        bpl -
        ldx #7
-       txa
        ora #SPRITES/64
        sta SCREEN+$3f8,x
        lda spr_col,x
        sta SPR0_COLOR,x
        dex
        bpl -
        lda #$ff
        sta SPR_EXPAND_X
        sta SPR_EXPAND_Y
        sta SPR_ENABLE
        jsr move_sprites

        +set_irq irq_open, OPEN_IRQ
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *

; ---- line $f9: 24 rows -> the border flip-flop is never set -----------------
irq_open:
        +irq_enter
        lda #$13                ; DEN on, 24 rows (bit 3 = 0), YSCROLL 3
        sta VIC_CTRL1
        +set_irq irq_mid, MID_IRQ
        +irq_exit

; ---- mid screen: 25 rows again, move the sprites -----------------------------
irq_mid:
        +irq_enter
        lda #$1b
        sta VIC_CTRL1
        jsr move_sprites
        +set_irq irq_open, OPEN_IRQ
        +irq_exit

move_sprites:
        inc zp_t
        ldx #7
-       txa                     ; Y wave: sine[t*2 + i*32]
        asl
        asl
        asl
        asl
        asl
        clc
        adc zp_t
        adc zp_t
        tay
        lda wave,y              ; 0..12
        clc
        adc spr_y,x             ; top row 12, bottom row $f3
        pha
        txa
        asl
        tay
        pla
        sta SPR0_Y,y
        lda zp_t                ; X slides on a slow sine
        tay
        lda slide,y             ; 0..60
        clc
        adc spr_x,x
        pha
        txa
        asl
        tay
        pla
        sta SPR0_X,y
        dex
        bpl -
        rts

; letters -> sprite rows 4..11 (left byte), rest empty
make_sprites:
        lda #0
        tax
-       sta SPRITES,x
        sta SPRITES+$100,x
        inx
        bne -
        lda #$33                ; char ROM at $d000
        sta CPU_PORT
        ldx #7
.l:     lda letters,x
        asl
        asl
        asl
        sta zp_src
        lda #$d0
        adc #0
        sta zp_src+1
        txa                     ; dst = SPRITES + x*64 + 4*3
        lsr
        lsr
        clc
        adc #>SPRITES
        sta zp_dst+1
        txa
        and #3
        lsr
        ror
        ror                     ; (x & 3) * 64
        ora #12
        sta zp_dst
        ldy #0
-       lda (zp_src),y
        sty zp_t
        pha
        tya                     ; *3: sprite rows are 3 bytes
        asl
        adc zp_t
        tay
        pla
        sta (zp_dst),y
        ldy zp_t
        iny
        cpy #8
        bne -
        dex
        bpl .l
        lda #BANK_IO_ONLY
        sta CPU_PORT
        lda #0
        sta zp_t
        rts

nmi:    rti

letters: !scr "OPENCODE"
spr_x:  !for i, 0, 7 { !byte 60 + (i & 3) * 44 }
spr_y:  !byte 12, 12, 12, 12, $f3, $f3, $f3, $f3 ; + 0..12, letters at Y+8
spr_col: !byte 7, 13, 3, 14, 10, 8, 7, 1
text:   !scr "   the top and bottom borders are open  "

        !align 255, 0
wave:   !for i, 0, 255 { !byte int(6.5 + 6 * sin(float(i) * 2 * 3.14159265 / 256)) }
slide:  !for i, 0, 255 { !byte int(30.5 + 30 * sin(float(i) * 2 * 3.14159265 / 256)) }
