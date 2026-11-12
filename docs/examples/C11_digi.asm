; =============================================================================
; C11_digi.asm - C11 Digi samples (4-bit $d418 playback via NMI)
; What you see / hear: a drum loop (kick, snare, hi-hat) played as samples;
; the border flickers with the sample value.
; How:
; - the samples are synthesized at assemble time with ACME float maths
;   (kick = falling sine sweep, snare = noise + tone, hat = short noise),
;   one 4-bit value (0..15) per byte, 8 kHz, $80 marks the end
; - CIA2 timer A fires an NMI every 123 cycles (985248/123 = 8010 Hz);
;   the NMI handler writes the next value to the SID volume ($d418)
; - every write to the master volume makes a step in the SID output's DC
;   offset: that step IS the sample. A 6581 has a big DC offset, an 8580
;   almost none, so we also hold all 3 voices on a constant level (pulse
;   waveform + TEST bit, sustain 15): the volume then scales that DC on
;   both chips (8580 is still quieter and cleaner, the 6581 louder/buzzier)
; - the main loop starts a new sample every 12 frames from a pattern table
; Docs: docs/08-effects-library.md (C11), docs/05-music.md
; Limitations: 4-bit, 8 kHz; NMI costs ~35% of the CPU; any raster code
; running with it would get up to ~45 cycles of NMI jitter.
; =============================================================================
!source "c64.asm"

RATE    = 8000
TIMER   = 123                   ; cycles between NMIs (latch = TIMER-1)
STEP    = 12                    ; frames per pattern step
END     = $80                   ; end-of-sample marker

zp_step = $20                   ; pattern position
zp_wait = $21                   ; frames left in this step

        +basic_upstart

start:
        +demo_init nmi_rti
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$17
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_GREEN
        +fill_1000 COLOR_RAM
        ldx #title_end-title-1
-       lda title,x
        sta SCREEN+12*40+6,x
        dex
        bpl -

        ; SID: clear, then hold voices 1-3 at a constant DC level
        ldx #$18
        lda #0
-       sta SID,x
        dex
        bpl -
        ldx #14                 ; voice offsets 14, 7, 0
-       lda #$00
        sta SID+5,x             ; attack 0, decay 0
        lda #$f0
        sta SID+6,x             ; sustain 15
        lda #$49                ; pulse + TEST + gate: output held constant
        sta SID+4,x
        txa
        sec
        sbc #7
        tax
        bcs -

        lda #<silence           ; NMI plays from a safe pointer
        sta smp+1
        lda #>silence
        sta smp+2
        lda #<nmi_digi
        sta NMI_VECTOR
        lda #>nmi_digi
        sta NMI_VECTOR+1
        lda #<(TIMER-1)
        sta $dd04               ; CIA2 timer A latch
        lda #>(TIMER-1)
        sta $dd05
        lda #$81
        sta CIA2_ICR            ; enable timer A -> NMI
        lda #$11
        sta $dd0e               ; force load + start, continuous
        lda #1
        sta zp_wait
        lda #0
        sta zp_step

main:
-       lda VIC_RASTER          ; one pass per frame
        cmp #$fa
        bne -
-       lda VIC_RASTER
        cmp #$fa
        beq -
        dec zp_wait
        bne main
        lda #STEP
        sta zp_wait
        ldx zp_step
        inx
        txa
        and #7
        sta zp_step
        tax
        ldy pattern,x           ; 0 = rest, 1..3 = sample number
        beq main
        lda #$01
        sta CIA2_ICR            ; disable the NMI while the pointer changes
        lda smp_lo-1,y
        sta smp+1
        lda smp_hi-1,y
        sta smp+2
        lda #$81
        sta CIA2_ICR
        jmp main

; ---- NMI: one sample (7 entry + 30 + 6 rti cycles) ---------------------------
nmi_digi:
        pha                     ; 3
smp:    lda silence             ; 4  self-modified pointer
        bmi .end                ; 2
        sta SID_VOLUME          ; 4  low nibble = volume, filters off
        sta BORDER              ; 4  visual: border = sample value
        inc smp+1               ; 6
        bne +                   ; 3
        inc smp+2
+       bit CIA2_ICR            ; 4  acknowledge the NMI
        pla                     ; 4
nmi_rti:
        rti                     ; 6
.end:   bit CIA2_ICR
        pla
        rti

pattern: !byte 1, 3, 2, 3, 1, 1, 2, 3   ; kick hat snare hat kick kick snare hat
smp_lo:  !byte <kick, <snare, <hat
smp_hi:  !byte >kick, >snare, >hat
title:   !scr "C11 digi: 4-bit samples on $d418"
title_end:

silence: !byte END

; ---- samples, synthesized at assemble time ----------------------------------
!set seed = 1
kick:   ; 0.25 s: sine falling 160 -> 45 Hz, decaying
!for i, 0, RATE / 4 - 1 {
        !set t = float(i) / RATE
        !set ph = 2 * 3.14159265 * (45 * t + 115 * 0.04 * (1 - 2.718281828 ^ (-t / 0.04)))
        !set v = 7.5 + 7.5 * sin(ph) * 2.718281828 ^ (-t / 0.09)
        !byte int(v + 0.5)
}
        !byte END
snare:  ; 0.2 s: noise + 190 Hz tone, fast decay
!for i, 0, RATE / 5 - 1 {
        !set t = float(i) / RATE
        !set seed = (seed * 75 + 74) % 65537
        !set n = float(seed) / 32768 - 1
        !set v = 7.5 + 7.4 * (0.75 * n + 0.25 * sin(2 * 3.14159265 * 190 * t)) * 2.718281828 ^ (-t / 0.05)
        !byte int(v + 0.5)
}
        !byte END
hat:    ; 0.06 s: noise, very fast decay
!for i, 0, RATE * 6 / 100 - 1 {
        !set t = float(i) / RATE
        !set seed = (seed * 75 + 74) % 65537
        !set n = float(seed) / 32768 - 1
        !set v = 7.5 + 6 * n * 2.718281828 ^ (-t / 0.012)
        !byte int(v + 0.5)
}
        !byte END
