; =============================================================================
; A10_text_reveal.asm - A10 Text reveal / wipe
; What you see: a block of text appears column by column (left to right),
; stays, vanishes, then appears again cell by cell in a random order. Loops.
; Technique:
; - the screen RAM holds the text all the time; colour RAM starts BLACK
;   (same as the background), so nothing is visible
; - the "real" colours live in a 1000-byte shadow buffer (SHADOW)
; - column wipe: each frame, copy one column of SHADOW to colour RAM
; - random wipe: a 10-bit Galois LFSR (x^10+x^7+1) visits 1..1023 once each;
;   values < 1000 are cell numbers. 31 cells/frame, 33 frames = 1023 steps
; Docs: docs/08-effects-library.md (A10)
; =============================================================================
!source "c64.asm"

TEXT_ROW    = 7
TEXT_ROWS   = 11
TEXT_COL    = 4
HOLD        = 100               ; frames the text stays fully visible
REVEAL_RATE = 31                ; random cells per frame (31 * 33 = 1023)
LFSR_MASK   = $240              ; taps for x^10 + x^7 + 1 (period 1023)
SHADOW      = $3000             ; 1000 bytes: target colour of every cell

zp_src      = $20               ; 2 bytes
zp_dst      = $22               ; 2 bytes
lfsr        = $24               ; 2 bytes
state       = $26               ; 0 wipe, 1 hold, 2 random, 3 hold
timer       = $27
col         = $28
count       = $29
frame_flag  = $2a
line        = $2b
zp_sh       = $2c               ; 2 bytes: SHADOW row pointer

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$17                ; screen $0400, lower/upper case ROM font
        sta VIC_MEMPTR
        lda #$20
        +fill_1000 SCREEN
        lda #BLACK
        +fill_1000 COLOR_RAM
        jsr draw_text

        lda #0
        sta state
        sta col
        sta frame_flag

        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_frame, $fc
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag          ; wait for the bottom-of-frame IRQ
        beq main
        lda #0
        sta frame_flag
        jsr update
        jmp main

irq_frame:
        +irq_enter
        inc frame_flag
        +irq_exit

; ---- per-frame state machine ----------------------------------------------
update:
        lda state
        bne +
        jmp wipe_column
+       cmp #2
        bne hold
        jmp wipe_random

hold:   dec timer
        bne .r
        lda #BLACK              ; hide everything again
        +fill_1000 COLOR_RAM
        lda state               ; 1 -> 2 (random), 3 -> 0 (columns)
        clc
        adc #1
        and #3
        sta state
        lda #0
        sta col
        sta lfsr+1
        lda #1
        sta lfsr
        lda #1023/REVEAL_RATE
        sta count
.r:     rts

; one column of all 25 rows: SHADOW -> colour RAM
wipe_column:
        ldx col
        !for r, 0, 24 {
        lda SHADOW+r*40,x
        sta COLOR_RAM+r*40,x
        }
        inx
        stx col
        cpx #40
        bne +
        lda #1
        sta state
        lda #HOLD
        sta timer
+       rts

; REVEAL_RATE random cells: cell = LFSR value if < 1000
wipe_random:
        ldx #REVEAL_RATE
.step:  lsr lfsr+1              ; Galois LFSR step
        ror lfsr
        bcc +
        lda lfsr+1
        eor #>LFSR_MASK
        sta lfsr+1
        lda lfsr
        eor #<LFSR_MASK
        sta lfsr
+       lda lfsr+1              ; skip 1000..1023 (outside the screen)
        cmp #>1000
        bcc .ok
        bne .skip
        lda lfsr
        cmp #<1000
        bcs .skip
.ok:    lda lfsr
        sta zp_src
        sta zp_dst
        lda lfsr+1
        clc
        adc #>SHADOW
        sta zp_src+1
        lda lfsr+1
        clc
        adc #>COLOR_RAM
        sta zp_dst+1
        ldy #0
        lda (zp_src),y
        sta (zp_dst),y
.skip:  dex
        bne .step
        dec count
        bne +
        lda #3
        sta state
        lda #HOLD
        sta timer
+       rts

; ---- text into screen RAM, colours into SHADOW ------------------------------
draw_text:
        lda #BLACK              ; SHADOW = black everywhere
        +fill_1000 SHADOW
        lda #<text
        sta zp_src
        lda #>text
        sta zp_src+1
        lda #<(SCREEN+TEXT_ROW*40+TEXT_COL)
        sta zp_dst
        lda #>(SCREEN+TEXT_ROW*40+TEXT_COL)
        sta zp_dst+1
        lda #<(SHADOW+TEXT_ROW*40)
        sta zp_sh
        lda #>(SHADOW+TEXT_ROW*40)
        sta zp_sh+1
        lda #0
        sta line
.line:  ldy #0
-       lda (zp_src),y          ; copy one zero-terminated line
        beq .eol
        sta (zp_dst),y
        iny
        bne -
.eol:   iny                     ; skip the terminator
        tya
        clc
        adc zp_src
        sta zp_src
        bcc +
        inc zp_src+1
+       ldx line                ; whole row of SHADOW = this line's colour
        lda row_colors,x
        ldy #39
-       sta (zp_sh),y
        dey
        bpl -
        lda zp_dst              ; next screen row and next SHADOW row
        clc
        adc #40
        sta zp_dst
        bcc +
        inc zp_dst+1
+       lda zp_sh
        clc
        adc #40
        sta zp_sh
        bcc +
        inc zp_sh+1
+       inc line
        lda line
        cmp #TEXT_ROWS
        bne .line
        rts

nmi:    rti

row_colors:
        !byte WHITE, GREY, LIGHT_BLUE, LIGHT_BLUE, LIGHT_BLUE, GREY
        !byte YELLOW, YELLOW, GREY, LIGHT_GREEN, WHITE

text:   ; avoid '@' (0 = end of line) and {|}~
        !scr "*** text reveal / wipe ***", 0
        !scr "", 0
        !scr "colour RAM starts black,", 0
        !scr "the text is already there:", 0
        !scr "we just give each cell its colour.", 0
        !scr "", 0
        !scr "pass 1: column by column", 0
        !scr "pass 2: random permutation", 0
        !scr "", 0
        !scr "opencode on the C64", 0
        !scr "codeurs en seine 2026", 0
