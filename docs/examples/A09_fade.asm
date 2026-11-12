; =============================================================================
; A09_fade.asm - A9 Fade in / out
; What you see: a colourful text screen (plus a strip of all 16 colours) fades
;   in from black, stays 3 s, fades out to black, waits 1 s, and loops.
; Technique:
; - the wanted colours are kept in a 1000-byte buffer (orig), copied once
;   from colour RAM after drawing the screen
; - 8 brightness levels: ramps[level*16 + c] = colour c made darker, following
;   the brightness order 0,6,9,11,2,4,8,12,14,10,5,15,3,7,13,1 (level 7 = black)
; - one fade step rewrites the whole colour RAM: $d800[i] = ramp[orig[i]]
;   (~17k cycles, one step every 3 frames); the border fades with it
; Docs: docs/08-effects-library.md (A9). See also Veto's colour ramps (cb:vic)
; Limitations: ramps follow brightness only, so a colour may shift hue while
;   it darkens (e.g. green -> light blue -> orange). Hand-made hue-preserving
;   ramps look nicer; only the ramps table needs to change.
; =============================================================================
!source "c64.asm"

ORIG       = $3000              ; 1000-byte copy of the wanted colours
STEP_DELAY = 3                  ; frames per fade step
HOLD_ON    = 150
HOLD_OFF   = 50
LEVELS     = 8

zp_ramp    = $20                ; 2-byte pointer to ramps + level*16
zp_level   = $22                ; 0 = full colour, LEVELS-1 = black
zp_state   = $23                ; 0 fade in, 1 hold, 2 fade out, 3 hold black
zp_delay   = $24
zp_src     = $25                ; print: text pointer
zp_dst     = $27                ; print: screen pointer
zp_col     = $29                ; print: colour RAM pointer

!macro print .row, .colour, .text {
        lda #<.text
        sta zp_src
        lda #>.text
        sta zp_src+1
        lda #<(SCREEN+.row*40)
        sta zp_dst
        sta zp_col
        lda #>(SCREEN+.row*40)
        sta zp_dst+1
        clc
        adc #>(COLOR_RAM-SCREEN)
        sta zp_col+1
        lda #.colour
        jsr print
}

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$17                ; ROM font lower/upper case
        sta VIC_MEMPTR
        lda #$20
        +fill_1000 SCREEN
        lda #BLACK
        +fill_1000 COLOR_RAM

        ; ---- draw the picture directly with its final colours ----------------
        +print 4, WHITE, t1
        +print 6, YELLOW, t2
        +print 8, LIGHT_GREEN, t3
        +print 10, CYAN, t4
        +print 12, LIGHT_RED, t5
        +print 14, PURPLE, t6
        ldx #39                 ; row 18: all 16 colours as solid blocks
-       lda #$a0
        sta SCREEN+18*40,x
        sta SCREEN+19*40,x
        txa
        lsr
        and #15
        sta COLOR_RAM+18*40,x
        sta COLOR_RAM+19*40,x
        dex
        bpl -

        ; ---- orig = colour RAM (low nybble), then start black ----------------
        ldx #0
-       !for p, 0, 2 {
        lda COLOR_RAM+p*$100,x
        and #$0f
        sta ORIG+p*$100,x
        }
        lda COLOR_RAM+$2e8,x
        and #$0f
        sta ORIG+$2e8,x
        inx
        bne -
        lda #LEVELS-1
        sta zp_level
        jsr apply_level
        lda #3
        sta zp_state
        lda #HOLD_OFF
        sta zp_delay

main_loop:
-       lda VIC_RASTER          ; wait for line $ff (bottom border)
        cmp #$ff
        bne -
        jsr fade_script
-       lda VIC_RASTER
        cmp #$ff
        beq -
        jmp main_loop

fade_script:
        dec zp_delay
        bne .done
        lda #STEP_DELAY         ; default delay to the next step
        sta zp_delay
        ldx zp_state
        beq .in
        dex
        beq .hold_on
        dex
        beq .out
        lda #0                  ; state 3 (hold black) -> fade in
        sta zp_state
.done:  rts
.hold_on:
        lda #2                  ; hold done -> fade out
        sta zp_state
        rts
.in:    dec zp_level
        jsr apply_level
        lda zp_level
        bne .done
        lda #1                  ; fully visible -> hold
        sta zp_state
        lda #HOLD_ON
        sta zp_delay
        rts
.out:   inc zp_level
        jsr apply_level
        lda zp_level
        cmp #LEVELS-1
        bne .done
        lda #3                  ; black -> wait
        sta zp_state
        lda #HOLD_OFF
        sta zp_delay
        rts

; colour RAM = ramp(level)[orig], ~17k cycles
apply_level:
        lda zp_level
        asl
        asl
        asl
        asl
        clc
        adc #<ramps             ; ramps is page aligned: no carry
        sta zp_ramp
        lda #>ramps
        sta zp_ramp+1
        ldy #LIGHT_BLUE         ; border fades too
        lda (zp_ramp),y
        sta BORDER
        ldx #0
-       !for p, 0, 2 {
        ldy ORIG+p*$100,x       ; 4
        lda (zp_ramp),y         ; 5
        sta COLOR_RAM+p*$100,x  ; 5
        }
        ldy ORIG+$2e8,x         ; overlaps, ends exactly at +999
        lda (zp_ramp),y
        sta COLOR_RAM+$2e8,x
        inx
        bne -
        rts

; zero-terminated text at zp_src -> zp_dst, colour A -> zp_col
print:  ldy #0
        tax
-       lda (zp_src),y
        beq +
        sta (zp_dst),y
        txa
        sta (zp_col),y
        iny
        bne -
+       rts

nmi:    rti

t1:     !scr "           codeurs en seine 2026", 0
t2:     !scr "         rouen - kindarena - 19 nov", 0
t3:     !scr "   fade tables: each colour gets darker", 0
t4:     !scr "   step by step through 8 levels...", 0
t5:     !scr "   ...down to black, then back up", 0
t6:     !scr "        opencode on a commodore 64", 0

        !align 255, 0
ramps:  ; 8 levels x 16 colours (generated from the brightness order)
        !byte $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f   ; level 0
        !byte $00,$07,$0b,$05,$02,$0a,$06,$0f,$04,$09,$0e,$0b,$08,$03,$0c,$0a   ; level 1
        !byte $00,$0f,$0b,$0a,$02,$0c,$06,$0a,$02,$06,$08,$09,$04,$05,$08,$0e   ; level 2
        !byte $00,$0a,$09,$0c,$0b,$08,$06,$0c,$0b,$06,$04,$09,$02,$0e,$04,$08   ; level 3
        !byte $00,$08,$09,$04,$09,$02,$00,$08,$0b,$06,$02,$06,$0b,$08,$0b,$04   ; level 4
        !byte $00,$02,$06,$0b,$06,$0b,$00,$02,$09,$06,$0b,$06,$09,$02,$09,$0b   ; level 5
        !byte $00,$09,$06,$09,$06,$06,$00,$09,$06,$00,$06,$00,$06,$09,$06,$09   ; level 6
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; level 7
