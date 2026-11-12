; =============================================================================
; B21_charset_blend.asm - B21 Charset blend-in
; What you see: a text page (with reversed banner lines) appears pixel by
; pixel, holds, then dissolves away pixel by pixel, in a loop.
; Technique:
; - the screen shows a RAM charset at $2000 that starts empty;
; - the real glyphs (ROM font copy) sit in a hidden "target" charset at $3000;
; - each step turns on (or off) one pixel position (row r, bit b) of the 8x8
;   cell in all 256 chars: charset = target AND rowmask[r];
; - the 64 pixel positions are visited in a pseudo-random order (table built
;   at assemble time), so the picture fades in like a dissolve.
; Docs: docs/08-effects-library.md (B21)
; Based on: codebase64 base:8x8_charset_pixel-blend-in, rewritten
; =============================================================================
!source "c64.asm"

CHARSET = $2000                 ; charset the VIC displays (2 KB)
TARGET  = $3000                 ; hidden copy of the full font (2 KB)
STEP_FRAMES = 2                 ; frames per pixel step (64 steps)
HOLD_ON  = 60                   ; steps to hold the full picture
HOLD_OFF = 15                   ; steps to hold the empty screen

mask    = $20                   ; zero page
state   = $21                   ; 0 = blend in, 1 = hold, 2 = blend out, 3 = hold
step    = $22                   ; 0..63 position in perm table
delay   = $23
hold    = $24

        +basic_upstart

start:
        +demo_init nmi
        ; copy the ROM font (lower/upper case set, 256 chars) to TARGET,
        ; clear the displayed charset. $01=$33: char ROM at $d000, IRQs are off.
        lda #$33
        sta CPU_PORT
        ldx #0
-       !for p, 0, 7 {
        lda $d800+p*$100,x
        sta TARGET+p*$100,x
        lda #0
        sta CHARSET+p*$100,x
        }
        inx
        bne -
        lda #BANK_IO_ONLY
        sta CPU_PORT

        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM

        ; print the text page: each line = (row, colour, reverse flag, text)
        lda #<page
        sta $2b
        lda #>page
        sta $2c
.line   ldy #0
        lda ($2b),y             ; row (or $ff = end)
        bmi .done
        tax
        lda rowlo,x
        sta $25                 ; $25/$26 -> screen row
        sta $27                 ; $27/$28 -> colour RAM row
        lda rowhi,x
        sta $26
        clc
        adc #(>COLOR_RAM)-(>SCREEN)
        sta $28
        iny
        lda ($2b),y             ; colour
        sta $29
        iny
        lda ($2b),y             ; $00 or $80 (reverse)
        sta $2a
        lda $2b                 ; skip the 3 header bytes
        clc
        adc #3
        sta $2b
        bcc +
        inc $2c
+       ldy #0
-       lda ($2b),y
        beq +
        ora $2a
        sta ($25),y
        lda $29
        sta ($27),y
        iny
        bne -
+       iny                     ; skip the 0 terminator
        tya
        clc
        adc $2b
        sta $2b
        bcc .line
        inc $2c
        jmp .line
.done
        lda #$18                ; screen $0400, charset $2000
        sta VIC_MEMPTR
        lda #STEP_FRAMES
        sta delay
        lda #0
        sta state
        sta step

main:
-       lda VIC_RASTER          ; one update per frame, below the display
        cmp #$fb
        bne -
        jsr update
-       lda VIC_RASTER
        cmp #$fb
        beq -
        jmp main

; ---- state machine, one pixel position every STEP_FRAMES frames ------------
update:
        dec delay
        bne .rts
        lda #STEP_FRAMES
        sta delay
        lda state
        and #1
        beq .blend              ; states 0 and 2
        dec hold                ; states 1 and 3: wait
        bne .rts
        beq .next
.blend  ldy step
        lda perm,y
        tay
        lsr
        lsr
        lsr
        tax                     ; X = pixel row 0..7
        tya
        and #7
        tay                     ; Y = bit 0..7
        lda state
        bne .off
        lda rowmask,x           ; blend in: set the bit
        ora bits,y
        jmp .set
.off    lda bits,y              ; blend out: clear the bit
        eor #$ff
        and rowmask,x
.set    sta rowmask,x
        jsr apply_row
        inc step
        lda step
        cmp #64
        bne .rts
        lda #0
        sta step
        lda state               ; entering a hold state
        cmp #2
        lda #HOLD_ON
        bcc +
        lda #HOLD_OFF
+       sta hold
.next   inc state
        lda state
        and #3
        sta state
.rts    rts

; charset[c*8+r] = target[c*8+r] AND rowmask[r] for all 256 chars (X = r)
apply_row:
        lda rowmask,x
        sta mask
-       !for p, 0, 7 {
        lda TARGET+p*$100,x
        and mask
        sta CHARSET+p*$100,x
        }
        txa
        clc
        adc #8                  ; next char, same pixel row
        tax
        bcc -                   ; 32 chars per page
        rts

nmi:    rti

rowmask: !fill 8, 0
bits:   !byte $80, $40, $20, $10, $08, $04, $02, $01
; 64 pixel positions (row*8+bit) in a scrambled order: odd multiplier mod 64
; and an XOR are both bijective, so every position appears exactly once.
perm:   !for i, 0, 63 { !byte ((i * 45 + 7) & 63) XOR $2a }
rowlo:  !for r, 0, 24 { !byte <(SCREEN + r * 40) }
rowhi:  !for r, 0, 24 { !byte >(SCREEN + r * 40) }

page:   !byte 4, WHITE, $80
        !scr "                                        ", 0
        !byte 5, WHITE, $80
        !scr "      codeurs en seine 2026 - rouen     ", 0
        !byte 6, WHITE, $80
        !scr "                                        ", 0
        !byte 10, YELLOW, 0
        !scr "   charset pixel blend-in:", 0
        !byte 12, LIGHT_GREEN, 0
        !scr "   every frame, one of the 64 pixel", 0
        !byte 13, LIGHT_GREEN, 0
        !scr "   positions of the 8x8 cell is copied", 0
        !byte 14, LIGHT_GREEN, 0
        !scr "   from a hidden font into the charset", 0
        !byte 15, LIGHT_GREEN, 0
        !scr "   for all 256 characters at once.", 0
        !byte 19, CYAN, $80
        !scr "    opencode on a commodore 64    ", 0
        !byte $ff
