; =============================================================================
; A08_beat_flash.asm - A8 Border / background flash
; What you see: the screen flashes white on a beat and fades back to black
;   in 8 frames; "kick" steps flash the whole screen, "snare" steps only the
;   border.
; Technique:
; - a frame counter steps through an 8-step beat table every BEAT_FRAMES
;   frames (12 frames = 125 BPM in eighths at 50 Hz)
; - on a hit: fade index = 0; then every frame $d020 (and $d021 for a kick)
;   = fade[index++] until the end of the table (white -> greys -> black)
; - with music, trigger from the player instead (e.g. a drum note)
; Docs: docs/08-effects-library.md (A8)
; =============================================================================
!source "c64.asm"

BEAT_FRAMES = 12

zp_timer = $20                  ; frames until the next step
zp_step  = $21                  ; 0..7
zp_fade  = $22                  ; index in fade, FADE_LEN = idle
zp_kind  = $23                  ; 1 = border only, 2 = border + background

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
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM
        ldx #text_end-text-1
-       lda text,x
        sta SCREEN+12*40+(40-(text_end-text))/2,x
        dex
        bpl -
        lda #1
        sta zp_timer
        lda #FADE_LEN
        sta zp_fade

main_loop:
-       lda VIC_RASTER          ; wait for line $ff (bottom border)
        cmp #$ff
        bne -
        jsr beat
        jsr flash
-       lda VIC_RASTER
        cmp #$ff
        beq -
        jmp main_loop

beat:   dec zp_timer            ; next step of the beat table?
        bne .no
        lda #BEAT_FRAMES
        sta zp_timer
        lda zp_step
        clc
        adc #1
        and #7
        sta zp_step
        tax
        lda beat_table,x
        beq .no                 ; 0 = rest
        sta zp_kind
        lda #0                  ; restart the fade
        sta zp_fade
.no:    rts

flash:  ldx zp_fade
        cpx #FADE_LEN
        bcs .idle
        lda fade,x
        sta BORDER
        ldy zp_kind
        cpy #2
        bne +
        sta BACKGROUND
+       inc zp_fade
.idle:  rts

nmi:    rti

beat_table:                     ; 2 = kick (full screen), 1 = snare (border), 0 = rest
        !byte 2, 0, 1, 0, 2, 2, 1, 0
fade:   !byte WHITE, WHITE, LIGHT_GREY, GREY, GREY, DARK_GREY, DARK_GREY, BLACK
FADE_LEN = * - fade

text:   !scr "boom ... tss ... boom boom tss"
text_end:
