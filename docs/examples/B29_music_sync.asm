; =============================================================================
; B29_music_sync.asm - B29 Music sync
; What you see: "Teh Disco" plays; the text jumps on every hit of voice 3,
; the border and background flash on every 4th hit, a VU bar follows voice 3's
; envelope and a counter shows the number of hits.
; Technique:
; - the SID tune is played once per frame from a raster IRQ (play = $1003);
; - SID register $d41c reads voice 3's envelope (ADSR output, 0-255), which is
;   readable while the other SID registers are write-only;
; - a "hit" is a jump of the envelope by more than HIT_STEP since the last
;   frame: it restarts a bounce table ($d011 Y scroll, changed in the bottom
;   border so the badlines aren't disturbed) and, every 4th hit, a fade table;
; - without a usable voice 3, use a beat table of frame numbers instead.
; Docs: docs/08-effects-library.md (B29), docs/05-music.md
; Music: Teh Disco by Jammer (2006), from HVSC, copyrighted: demo use only.
; Limitations: hits follow whatever voice 3 plays (in Teh Disco: a steady
; 8-frame on/off pattern), not necessarily the drums.
; =============================================================================
!source "c64.asm"

MUSIC_INIT = $1000
MUSIC_PLAY = $1003
HIT_STEP   = $30                ; minimum envelope rise to count as a hit
IRQ_LINE   = $fc                ; bottom border

env_prev = $20                  ; zero page (the player uses $fb-$fd)
flash    = $21                  ; index in the fade table (8 = idle)
hits     = $22
vu       = $23
frame_flag = $24
bounce_i = $25                  ; index in the bounce table (4 = idle)

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM
        lda #$17                ; screen $0400, ROM lowercase charset
        sta VIC_MEMPTR
        ldx #39
-       lda text1,x
        sta SCREEN+8*40,x
        lda text2,x
        sta SCREEN+10*40,x
        lda #WHITE
        sta COLOR_RAM+8*40,x
        dex
        bpl -
        ldx #text3_end-text3-1
-       lda text3,x
        sta SCREEN+12*40,x
        dex
        bpl -
        lda #8
        sta flash
        lda #4
        sta bounce_i
        lda #0
        sta hits
        sta env_prev
        jsr MUSIC_INIT          ; A = 0: first sub-tune

        lda #$1b
        sta VIC_CTRL1
        +set_irq irq, IRQ_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:
        lda frame_flag
        beq main
        lda #0
        sta frame_flag
        ; VU bar on row 14: vu/8 blocks (0..31), coloured by level
        ldx #0
-       txa
        asl
        asl
        asl
        cmp vu
        lda #$a0                ; solid block
        bcc +
        lda #$20
+       sta SCREEN+14*40+4,x
        lda vucol,x
        sta COLOR_RAM+14*40+4,x
        inx
        cpx #32
        bne -
        ; hit counter, 2 hex digits
        lda hits
        lsr
        lsr
        lsr
        lsr
        tax
        lda hex,x
        sta SCREEN+12*40+9
        lda hits
        and #15
        tax
        lda hex,x
        sta SCREEN+12*40+10
        jmp main

irq:
        +irq_enter
        jsr MUSIC_PLAY
        lda SID+$1c             ; voice 3 envelope
        tax
        sec
        sbc env_prev
        stx env_prev
        bcc +                   ; falling: no hit
        cmp #HIT_STEP
        bcc +
        lda #0                  ; hit: restart the bounce...
        sta bounce_i
        inc hits
        lda hits
        and #3
        bne +
        sta flash               ; ...and flash on every 4th hit (A = 0)
+       txa                     ; VU: peak with a slow fall (-12 per frame)
        cmp vu
        bcs +
        lda vu
        sbc #12-1               ; carry is clear: subtracts 12
        bcs +
        lda #0
+       sta vu
        ldx flash
        lda fade,x
        sta BORDER
        sta BACKGROUND
        cpx #8
        beq +
        inc flash
+       ldx bounce_i
        lda bounce,x            ; Y scroll, set in the border (no badline mess)
        ora #$18
        sta VIC_CTRL1
        cpx #4
        beq +
        inc bounce_i
+       inc frame_flag
        +irq_exit

nmi:    rti

;          0   1   2   3   4   5   6   7   8 (idle)
fade:   !byte 1, 1, 15, 12, 12, 11, 11, 0, 0
bounce: !byte 0, 1, 2, 3, 3            ;  4 = idle (normal Y scroll 3)
vucol:  !for i, 0, 31 { !byte (i < 16) * GREEN + (i >= 16) * (i < 26) * YELLOW + (i >= 26) * RED }
hex:    !scr "0123456789abcdef"
text1:  !scr "   music sync: teh disco by jammer      "
text2:  !scr "   bounce on voice 3 hits, flash on 4th "
text3:  !scr "   hits:"
text3_end:

        * = $1000
        !bin "assets/sid/Teh_Disco.sid",, $7e   ; skip PSID header + load address
