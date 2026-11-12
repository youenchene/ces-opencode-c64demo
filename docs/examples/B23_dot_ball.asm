; =============================================================================
; B23_dot_ball.asm - B23 3D dot ball
; What you see: a sphere of 128 dots spinning (tilted) in the middle of the
; screen.
; Technique:
; - a 16x15 char window (128x120 pixels) uses chars 0-239 laid out column by
;   column, so pixel (x,y) is at byte charset + (x/8)*120 + y;
; - the rotation is precalculated at assemble time (!for + sin/cos): for each
;   of the 8 latitude rings, 128 angles -> screen x and y. No multiply at run time;
; - two charsets ($2000/$2800) form a double buffer: draw into the hidden one,
;   then flip $d018 below the display. Old dots are erased from a list of the
;   bytes written two frames ago (no full clear).
; Docs: docs/08-effects-library.md (B23)
; Based on: codebase64 base:3d_dot_scroll and base:dots_and_plots, rewritten
; =============================================================================
!source "c64.asm"

BUF0    = $2000                 ; charset 0 (chars 240-255 stay blank)
BUF1    = $2800                 ; charset 1
WIN     = SCREEN + 5*40 + 12    ; top-left of the 16x15 window
TABLES  = $3000                 ; point tables (after the charsets)
NPTS    = 128                   ; 8 rings x 16 dots

ptr     = $20                   ; zero page
ptr2    = $22
idx     = $24                   ; angle index of the current dot
cnt     = $25
rot     = $26                   ; rotation angle 0..127
bufhi   = $27                   ; $20 or $28: buffer being drawn
ecnt    = $28                   ; erase list write index

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$ff                ; blank char everywhere
        +fill_1000 SCREEN
        ; clear both charsets
        lda #0
        tax
-       !for p, 0, 15 { sta BUF0+p*$100,x }
        inx
        bne -
        ; erase lists point at a harmless byte ($2000) to start with
-       sta elo,x
        sta ey,x
        inx
        bne -
        lda #>BUF0
-       sta ehi,x
        inx
        bne -

        ; window: screen code = col*15 + row, colour per row
        lda #<WIN
        sta ptr
        sta ptr2
        lda #>WIN
        sta ptr+1
        clc
        adc #(>COLOR_RAM)-(>SCREEN)
        sta ptr2+1
        ldx #0                  ; row
--      ldy #0                  ; col
        txa
-       sta (ptr),y
        clc
        adc #15
        iny
        cpy #16
        bne -
        lda rowcol,x
        ldy #15
-       sta (ptr2),y
        dey
        bpl -
        lda ptr
        clc
        adc #40
        sta ptr
        sta ptr2
        bcc +
        inc ptr+1
        inc ptr2+1
+       inx
        cpx #15
        bne --

        lda #>BUF1              ; first frame is drawn into BUF1
        sta bufhi

main:
-       lda VIC_RASTER          ; wait for the bottom border
        cmp #$fb
        bne -
        ; show the buffer that was drawn last, draw into the other one
        lda bufhi
        cmp #>BUF1
        lda #$18                ; screen $0400, charset $2000
        bcc +
        lda #$1a                ; screen $0400, charset $2800
+       sta VIC_MEMPTR
        lda bufhi
        eor #(>BUF0) XOR (>BUF1)
        sta bufhi
        jsr erase
        jsr draw
        inc rot
        lda rot
        and #127
        sta rot
        jmp main

; ---- erase the 128 bytes written into this buffer two frames ago ---------
erase:
        ldx #0
        lda bufhi
        cmp #>BUF1
        bcc +
        ldx #NPTS               ; BUF1 uses list entries 128-255
+       stx ecnt
        lda #NPTS
        sta cnt
-       lda elo,x               ; 4
        sta ptr                 ; 3
        lda ehi,x               ; 4
        sta ptr+1               ; 3
        ldy ey,x                ; 4
        lda #0                  ; 2
        sta (ptr),y             ; 6
        inx                     ; 2
        dec cnt                 ; 5
        bne -                   ; 3 = 36 cycles per dot
        rts

; ---- plot 8 rings x 16 dots ----------------------------------------------
draw:
        !for L, 0, 7 {
        lda rot
        sta idx
        lda #16
        sta cnt
-       ldy idx
        ldx xtab + L*128,y      ; screen x 0..127
        lda ytab + L*128,y      ; screen y 0..119
        tay
        lda collo,x             ; column start = (x/8)*120
        sta ptr
        lda colhi,x
        ora bufhi
        sta ptr+1
        lda (ptr),y
        ora bitmask,x
        sta (ptr),y
        tya                     ; remember the byte for erase
        ldy ecnt
        sta ey,y
        lda ptr
        sta elo,y
        lda ptr+1
        sta ehi,y
        inc ecnt
        lda idx                 ; next dot on the ring: +1/16 turn
        clc
        adc #8
        and #127
        sta idx
        dec cnt
        bne -
        }
        rts

nmi:    rti

rowcol: !byte 6, 6, 14, 14, 3, 3, 13, 1, 13, 3, 3, 14, 14, 6, 6

        * = TABLES
PI = 3.14159265
TILT = 0.45                     ; radians, tilt towards the viewer
; ring L at latitude (L-3.5)*0.36 rad; angle a = idx*2pi/128
;   x = cos(lat)*sin(a)          -> 64 + 56*x
;   y = sin(lat)*cos(t) - cos(lat)*cos(a)*sin(t)  -> 60 + 56*y
xtab:   !for L, 0, 7 { !for i, 0, 127 {
        !byte int(64.5 + 56 * cos((L - 3.5) * 0.36) * sin(i * 2 * PI / 128))
        } }
ytab:   !for L, 0, 7 { !for i, 0, 127 {
        !byte int(60.5 + 56 * (sin((L - 3.5) * 0.36) * cos(TILT) - cos((L - 3.5) * 0.36) * cos(i * 2 * PI / 128) * sin(TILT)))
        } }
collo:  !for x, 0, 127 { !byte <((x >> 3) * 120) }
colhi:  !for x, 0, 127 { !byte >((x >> 3) * 120) }
bitmask: !for x, 0, 127 { !byte $80 >> (x & 7) }
        !align 255, 0
elo:    !fill 256, 0            ; erase lists: 0-127 for BUF0, 128-255 for BUF1
ehi:    !fill 256, 0
ey:     !fill 256, 0
