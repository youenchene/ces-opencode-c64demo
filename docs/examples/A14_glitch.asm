; =============================================================================
; A14_glitch.asm - A14 Glitch / noise burst
; What you see: a calm text screen; every ~3 seconds a short "signal lost"
; burst (8 frames): the picture jumps sideways, the border flickers and a few
; rows fill with random chars in random colours. Then everything snaps back.
; Technique:
; - one raster IRQ at $fc (below the text) does the per-frame work
; - during the burst: random $d016 XSCROLL (0-7, 40 columns kept), random
;   $d020, and 3 random rows filled with random chars and colours
; - at the end: $d016/$d020 reset, screen and colour RAM redrawn
; - random numbers: 16-bit Galois LFSR
; Docs: docs/08-effects-library.md (A14)
; =============================================================================
!source "c64.asm"

INTERVAL = 150                  ; frames between bursts (3 s)
BURST    = 8                    ; frames per burst
GLITCH_ROWS = 3                 ; rows trashed per frame

zp_ptr     = $20                ; 2 bytes
rnd        = $22                ; 2 bytes
timer      = $24
burst      = $25
cnt        = $26

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        lda #BLUE
        sta BACKGROUND
        lda #$17
        sta VIC_MEMPTR
        jsr restore_screen
        lda #1
        sta rnd
        lda #0
        sta rnd+1
        sta burst
        lda #INTERVAL
        sta timer

        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_frame, $fc
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *                   ; everything happens in the IRQ

irq_frame:
        +irq_enter
        lda burst
        bne .glitch
        dec timer
        bne .done
        lda #BURST              ; start a burst
        sta burst
.glitch:
        jsr random              ; jump sideways
        and #7
        ora #$08                ; keep 40 columns
        sta VIC_CTRL2
        jsr random              ; flicker the border
        sta BORDER
        lda #GLITCH_ROWS
        sta cnt
-       jsr trash_row
        dec cnt
        bne -
        dec burst
        bne .done
        lda #$08                ; burst over: put everything back
        sta VIC_CTRL2
        lda #BLACK
        sta BORDER
        jsr restore_screen
        lda #INTERVAL
        sta timer
.done:  +irq_exit

; a random row (0-24) <- random chars in random colours
trash_row:
-       jsr random
        and #31
        cmp #25
        bcs -
        tax
        lda row_lo,x
        sta zp_ptr
        lda row_hi,x
        sta zp_ptr+1
        ldy #39
-       jsr random
        sta (zp_ptr),y          ; screen: any char (noise)
        lda zp_ptr+1
        eor #>(COLOR_RAM ^ SCREEN) ; same row in colour RAM ($04xx <-> $d8xx)
        sta zp_ptr+1
        jsr random
        sta (zp_ptr),y          ; colour: only the low nybble counts
        lda zp_ptr+1
        eor #>(COLOR_RAM ^ SCREEN)
        sta zp_ptr+1
        dey
        bpl -
        rts

restore_screen:
        lda #$20
        +fill_1000 SCREEN
        ldx #0                  ; text: 5 rows x 40 = 200 bytes, rows 9-13
-       lda text,x
        sta SCREEN+9*40,x
        inx
        cpx #200
        bne -
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM
        ldx #39
        lda #WHITE
-       sta COLOR_RAM+9*40,x    ; title row in white
        dex
        bpl -
        rts

random: lsr rnd+1               ; 16-bit Galois LFSR, returns low byte
        ror rnd
        bcc +
        lda rnd+1
        eor #$b4
        sta rnd+1
+       lda rnd
        rts

nmi:    rti

row_lo: !for r, 0, 24 { !byte <(SCREEN+r*40) }
row_hi: !for r, 0, 24 { !byte >(SCREEN+r*40) }

text:   ; 5 rows x 40 columns
        !scr "         A14 glitch / noise burst       "
        !scr "                                        "
        !scr "   every 3 seconds the signal drops:    "
        !scr "  random xscroll, border, colour rows   "
        !scr "       ...then it snaps back.           "
