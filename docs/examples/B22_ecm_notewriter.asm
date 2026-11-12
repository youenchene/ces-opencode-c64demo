; =============================================================================
; B22_ecm_notewriter.asm - B22 ECM note writer
; What you see: a "note" is typed on screen; title lines and the cursor sit on
; coloured background boxes that flash through colour ramps.
; Technique:
; - Extended Colour Mode ($d011 bit 6): only chars 0-63 are available, and
;   bits 6-7 of each screen code pick the char's background colour from
;   $d021, $d022, $d023 or $d024;
; - the typer ORs a "background select" ($00/$40/$80/$c0) onto each char;
; - every frame $d022-$d024 are cycled through colour ramps: all the boxes
;   flash without touching screen or colour RAM.
; Docs: docs/08-effects-library.md (B22)
; Based on: codebase64 base:colour_flashing_notewriter_style, rewritten
; Limitations: ECM shows 64 chars only: lowercase letters, digits, punctuation.
; =============================================================================
!source "c64.asm"

TYPE_DELAY = 2                  ; frames per character
WAIT_END   = 200                ; frames before the page restarts

txt     = $20                   ; zero page: text pointer
scr     = $22                   ; screen write pointer
line    = $24                   ; start of the current line
sel     = $26                   ; background select bits ($00/$40/$80/$c0)
delay   = $27
frame   = $28

; text control bytes
BG0 = $f0 : BG1 = $f1 : BG2 = $f2 : BG3 = $f3
NL  = $fe : END = $ff

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #WHITE
        +fill_1000 COLOR_RAM
        lda #$5b                ; ECM on, DEN, 25 rows, yscroll 3
        sta VIC_CTRL1
        lda #$16                ; screen $0400, ROM charset $1800 (lowercase)
        sta VIC_MEMPTR

restart:
        lda #$20                ; spaces on background 0
        +fill_1000 SCREEN
        lda #<text
        sta txt
        lda #>text
        sta txt+1
        lda #<(SCREEN + 3*40 + 2)
        sta scr
        sta line
        lda #>(SCREEN + 3*40 + 2)
        sta scr+1
        sta line+1
        lda #0
        sta sel
        lda #TYPE_DELAY
        sta delay

main:
-       lda VIC_RASTER          ; once per frame, below the display
        cmp #$fb
        bne -
        jsr flash
        dec delay
        bne .wait
        lda #TYPE_DELAY
        sta delay
        jsr type_char
        bcs .end                ; carry set = end of text
.wait
-       lda VIC_RASTER
        cmp #$fb
        beq -
        jmp main

.end    ldx #WAIT_END           ; keep the page (still flashing), then restart
--
-       lda VIC_RASTER
        cmp #$fb
        bne -
        jsr flash
-       lda VIC_RASTER
        cmp #$fb
        beq -
        dex
        bne --
        jmp restart

; ---- cycle the 3 extra background colours -----------------------------------
flash:
        inc frame
        lda frame
        lsr                     ; half speed
        and #15
        tay
        lda ramp_blue,y
        sta BGCOLOR1            ; $d022: select $40
        lda ramp_red,y
        sta BGCOLOR2            ; $d023: select $80
        lda ramp_grey,y
        sta BGCOLOR3            ; $d024: select $c0
        rts

; ---- type one character; returns carry set at the end of the text --------
type_char:
        ldy #0
-       lda (txt),y
        inc txt
        bne +
        inc txt+1
+       cmp #END
        beq .fin
        cmp #NL
        beq .nl
        cmp #BG0
        bcc .char
        and #3                  ; BG0..BG3 -> select bits 6-7
        lsr
        ror
        ror
        sta sel
        jmp -                   ; control bytes cost no time
.nl     lda line                ; next line
        clc
        adc #40
        sta line
        sta scr
        lda line+1
        adc #0
        sta line+1
        sta scr+1
        jmp -
.char   and #$3f                ; ECM: 64 chars only
        ora sel
        sta (scr),y
        inc scr
        bne +
        inc scr+1
+       lda #$20 | $c0          ; cursor: a space on the flashing $d024 box
        sta (scr),y
        clc
        rts
.fin    lda #$20                ; remove the cursor
        sta (scr),y
        sec
        rts

nmi:    rti

ramp_blue: !byte 6, 6, 6, 11, 4, 14, 3, 1, 1, 3, 14, 4, 11, 6, 6, 6
ramp_red:  !byte 2, 2, 9, 2, 8, 10, 15, 7, 7, 15, 10, 8, 2, 9, 2, 2
ramp_grey: !byte 0, 11, 12, 15, 1, 1, 15, 12, 11, 0, 0, 0, 0, 0, 0, 0

text:   !byte BG1
        !scr "                                    "
        !byte BG0, NL, BG1
        !scr "    codeurs en seine 2026 - rouen   "
        !byte BG0, NL, BG1
        !scr "                                    "
        !byte BG0, NL, NL
        !scr "hello from the note writer!", NL, NL
        !scr "this is extended colour mode: every", NL
        !scr "character picks one of four", NL
        !scr "background colours with bits 6-7 of", NL
        !scr "its screen code.", NL, NL
        !scr "$d021 "
        !byte BG1
        !scr " $d022 "
        !byte BG0
        !scr " "
        !byte BG2
        !scr " $d023 "
        !byte BG0
        !scr " "
        !byte BG3
        !scr " $d024 "
        !byte BG0, NL, NL
        !scr "flashing = just rewrite $d022-$d024", NL
        !scr "once per frame. zero cpu cost.", NL, NL, NL
        !byte BG3
        !scr " opencode on a c64 "
        !byte BG0, END
