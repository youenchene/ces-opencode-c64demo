; =============================================================================
; C07_twister.asm - C7 Twister (2nd-line FLI)
; What you see: a shaded square bar in the middle of the screen, twisting
; and rotating around its vertical axis (blue/cyan, multicolour).
; How:
; - the bar's cross-section is pre-rendered at 32 rotation steps (0..90 deg)
;   as one-line "fragments", 32 chars wide (128 MC pixels), each char holding
;   the same byte on all 8 lines (so the char row line doesn't matter)
; - 8 charsets x 4 screens (VIC bank 1) hold the 32 fragments: one $d018
;   value = one fragment (screen picks the 32-char block, charset the data)
; - every 2nd raster line a badline is forced ($d011 YSCROLL = next line & 7),
;   so the VIC re-reads the screen (new $d018 screen) and RC restarts at 0,
;   which also keeps VCBASE on screen row 0: each screen only needs one row
; - the forced badline halts the CPU until cycle 55: the loop resyncs itself
;   each pair, only a $d012 poll is needed to place the $d018 write in the
;   cycles 6..12 window before the screen fetch (no FLI bug: condition is
;   true from cycle 0)
; - main loop: per-pair angle = base + i*twist, twist follows a sine
; Docs: docs/08-effects-library.md (C7)
; Based on: codebase64 base:twisters_x-rotators_and_waving_carpets by
;           Bitbreaker, rewritten (simplified: no cover sprites, no interlace)
; Limitations: 2-line vertical resolution, 32 rotation steps per 90 degrees.
; =============================================================================
!source "c64.asm"

IRQ_LINE = $2f                  ; before the first badline ($33, YSCROLL 3)
FIRST    = $33                  ; first (natural) badline of the twister
NPAIRS   = 99                   ; $33..$f7: last line where a badline works
RIN      = 30                   ; inradius of the square, in MC pixels
CHARSETS = $4000                ; charset k at $4000+k*$800 (first $400 used)
SCREENS  = $4400                ; screen s at $4400+s*$800 (only row 0 used)
BLANK    = $fe                  ; char $fe ($7f0) is empty in every charset

zp_t     = $20
zp_base  = $21                  ; 2 bytes, 8.8 angle of the top pair
zp_ang   = $23                  ; 2 bytes
zp_step  = $25                  ; 2 bytes, signed 8.8 twist per pair

        +basic_upstart

start:
        +demo_init nmi
        lda CIA2_PRA
        and #$fc
        ora #$02                ; VIC bank 1 ($4000-$7fff)
        sta CIA2_PRA
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #CYAN               ; MC 01: lit face
        sta BGCOLOR1
        lda #LIGHT_BLUE         ; MC 10: half lit
        sta BGCOLOR2
        lda #$08+BLUE           ; MC 11 (colour RAM): dark face, bit3 = MC
        +fill_1000 COLOR_RAM
        lda #$18                ; multicolour, 40 columns
        sta VIC_CTRL2
        lda #$1b
        sta VIC_CTRL1
        jsr compute
        +set_irq irq, IRQ_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag
        beq main
        lda #0
        sta frame_flag
        jsr compute
        jmp main

; ---- build tab18 (one $d018 value per line pair) ---------------------------
compute:
        inc zp_t
        ldx zp_t
        lda sintab,x            ; twist = sine (signed 8.8, +-0.5 step/pair)
        sta zp_step
        ldy #0
        cmp #$80
        bcc +
        dey
+       sty zp_step+1
        lda zp_base             ; spin: +0.6 step per frame
        clc
        adc #$a0
        sta zp_base
        sta zp_ang
        lda zp_base+1
        adc #0
        sta zp_base+1
        sta zp_ang+1
        ldx #0
-       lda zp_ang+1
        and #31
        tay
        lda frag18,y
        sta tab18,x
        lda zp_ang
        clc
        adc zp_step
        sta zp_ang
        lda zp_ang+1
        adc zp_step+1
        sta zp_ang+1
        inx
        cpx #NPAIRS
        bne -
        rts

nmi:    rti
frame_flag: !byte 0

; -----------------------------------------------------------------------------
; Raster code. Each pass of pair_loop takes one line pair: it is halted by
; the forced badline (cycle 12..54) and resumes at cycle 55, so there is no
; drift and no stable-raster setup is needed.
; -----------------------------------------------------------------------------
        !align 255, 0
irq:
        +irq_enter
        ldx #0
pair_loop:
        lda tab11,x             ; 4  YSCROLL = line_i & 7 -> badline on line_i
        sta VIC_CTRL1           ; 4  (any time in the 2 lines before is fine)
        ldy tab18,x             ; 4
        lda tabln,x             ; 4
-       cmp VIC_RASTER          ; 4  wait for line_i (read on 4th cycle)
        bne -                   ; 3/2
        sty VIC_MEMPTR          ; 4  write lands at cycle 6..12 of line_i,
        inx                     ; 2  before the c-accesses (cycle 15)
        cpx #NPAIRS             ; 2
        bne pair_loop           ; 3  next 'lda' gets halted by the badline
        lda #$1b                ; normal YSCROLL: no more badlines ($fb > $f7)
        sta VIC_CTRL1
        inc frame_flag
        +irq_exit

        !align 255, 0
tab18:  !fill NPAIRS, $10
        !align 255, 0
tab11:  !for i, 0, NPAIRS-1 { !byte ((FIRST + 2*i) & 7) | $18 }
        !align 255, 0
tabln:  !for i, 0, NPAIRS-1 { !byte FIRST + 2*i }
        ; fragment f -> charset f>>2, screen f&3
frag18: !for f, 0, 31 { !byte ((1 + 2*(f & 3)) << 4) | ((f >> 2) << 1) }
        !align 255, 0
sintab: !for i, 0, 255 { !byte int(127 * sin(float(i) * 2 * 3.14159265 / 256)) & $ff }

; ---- VIC bank 1 data, generated at assemble time ----------------------------
; fragment f = rotation f*90/32 deg. Face j has normal angle phi = (f+32j)*pi/64,
; it is visible if cos(phi) > 0, centred at 64+RIN*sin(phi), half-width
; RIN*cos(phi); shade (MC code 1..3) from cos(phi).
!for f, 0, 31 {
        * = CHARSETS + (f >> 2) * $800 + (f & 3) * $100
        !for c, 0, 31 {
                !set b = 0
                !for p, 0, 3 {
                        !set code = 0
                        !for j, 0, 3 {
                                !set phi = float(f + 32 * j) * 3.14159265 / 64
                                !set cs = cos(phi)
                                !if cs > 0.01 {
                                        !set d = float(c * 4 + p) + 0.5 - (64 + RIN * sin(phi))
                                        !if d < 0 { !set d = -d }
                                        !if d < RIN * cs {
                                                !if cs > 0.9 {
                                                        !set code = 1
                                                } else {
                                                        !if cs > 0.55 { !set code = 2 } else { !set code = 3 }
                                                }
                                        }
                                }
                        }
                        !set b = b | (code << (6 - 2 * p))
                }
                !fill 8, b
        }
}
; screens: row 0 = 4 blank chars, chars s*32..s*32+31, 4 blank chars.
; Their bytes $3f0-$3f7 are char $fe of charsets 0-3: left zero = blank.
!for s, 0, 3 {
        * = SCREENS + s * $800
        !fill 4, BLANK
        !for c, 0, 31 { !byte s * 32 + c }
        !fill 4, BLANK
        * = SCREENS + s * $800 + $3f0
        !fill 8, 0
}
!for k, 4, 7 {
        * = CHARSETS + k * $800 + BLANK * 8
        !fill 8, 0
}
