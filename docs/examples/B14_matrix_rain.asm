; =============================================================================
; B14_matrix_rain.asm - B14 Matrix rain
; What you see: green glyphs falling down 40 columns at different speeds.
; How:
; - screen RAM is filled once with random glyphs; colour RAM starts black,
;   so the rain is drawn by colour RAM only (plus a new glyph at each head)
; - per column: head row (signed: negative = waiting), speed and timer
; - when a column steps, it colours rows head, head-1, head-3, head-6, head-10
;   with 1 (white), 13, 5, 11, 0: every row fades as the head moves away
; - when the tail leaves the screen, the column restarts with a random
;   delay and speed (8-bit LFSR)
; Docs: docs/08-effects-library.md (B14)
; =============================================================================
!source "c64.asm"

TAIL_LEN = 10                   ; last tail offset (erased to black)

zp_rnd  = $20
zp_col  = $21                   ; current column
zp_t    = $22                   ; tail step index
zp_c    = $23                   ; colour to plot
zp_ptr  = $24                   ; 2 bytes: colour RAM row
zp_sptr = $26                   ; 2 bytes: screen row

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$15                ; ROM font, upper case + graphics
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        lda #$c8
        sta VIC_CTRL2
        lda #BLACK
        +fill_1000 COLOR_RAM
        lda #$a7
        sta zp_rnd
        ldx #0                  ; random glyphs everywhere
-       !for p, 0, 3 {
        jsr rnd
        and #$7f
        sta SCREEN+p*250,x
        }
        inx
        cpx #250
        bne -
        ldx #39                 ; random start delays and speeds
-       jsr new_drop
        dex
        bpl -

main:
-       lda VIC_RASTER          ; one step per frame, below the text area
        cmp #$fb
        bne -
        jsr rain
-       lda VIC_RASTER
        cmp #$fb
        beq -
        jmp main

; ---- update all 40 columns ---------------------------------------------------
rain:
        ldx #39
.col:   dec timer,x
        bne .next
        lda speed,x
        sta timer,x
        inc head,x
        stx zp_col
        lda #0
        sta zp_t
.tail:  ldy zp_t                ; plot each tail step
        lda tail_col,y
        sta zp_c
        lda head,x
        sec
        sbc tail_off,y          ; row = head - offset (signed)
        jsr plot
        ldx zp_col
        inc zp_t
        lda zp_t
        cmp #5
        bne .tail
        lda head,x              ; tail end below the screen? restart
        bmi .next
        cmp #25+TAIL_LEN
        bcc .next
        jsr new_drop
.next:  dex
        bpl .col
        rts

; A = row (signed), zp_c = colour, zp_col = column. Head also gets a new glyph.
plot:
        cmp #25                 ; negative rows are >= 128 unsigned: skipped too
        bcs .out
        tax
        lda row_lo,x
        sta zp_ptr
        sta zp_sptr
        lda row_hi,x
        sta zp_sptr+1
        ora #>COLOR_RAM         ; $04xx -> $d8xx (row_hi is the screen page)
        eor #>SCREEN
        sta zp_ptr+1
        ldy zp_col
        lda zp_c
        sta (zp_ptr),y
        cmp #WHITE
        bne .out
        jsr rnd                 ; head: fresh random glyph
        and #$7f
        sta (zp_sptr),y
.out:   rts

; column X: wait 0..31 frames above the screen, speed 1..4 frames per row
new_drop:
        jsr rnd
        and #31
        eor #$ff                ; -(n+1)
        sta head,x
        jsr rnd
        and #3
        clc
        adc #1
        sta speed,x
        sta timer,x
        rts

; 8-bit Galois LFSR (period 255). Returns A, keeps X/Y.
rnd:    lda zp_rnd
        asl
        bcc +
        eor #$1d
+       sta zp_rnd
        rts

nmi:    rti

tail_off: !byte 0, 1, 3, 6, TAIL_LEN
tail_col: !byte WHITE, LIGHT_GREEN, GREEN, DARK_GREY, BLACK
row_lo: !for r, 0, 24 { !byte <(SCREEN + r*40) }
row_hi: !for r, 0, 24 { !byte >(SCREEN + r*40) }
head:   !fill 40, 0
speed:  !fill 40, 0
timer:  !fill 40, 0
