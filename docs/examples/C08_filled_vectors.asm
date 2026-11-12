; =============================================================================
; C08_filled_vectors.asm - C8 Filled 3D vectors
; What you see: a solid cube (yellow / orange / red faces) tumbling in the
; middle of the screen, drawn with filled polygons, ~17-25 frames per second.
; How:
; - canvas = 16x15 multicolour chars (64x120 MC pixels) laid out column by
;   column: byte (column c, line y) = charset + 128 + c*120 + y, so a whole
;   column is one linear 120-byte strip (fast fill, fast clear)
; - two charsets ($2000 / $2800): we draw into the hidden one, then the IRQ
;   flips $d018 at the bottom of the frame (double buffering, no flicker)
; - per visible face: each edge is walked with an 8.8 slope (one 16/8
;   division per edge) and stretches min x / max x tables per raster line;
;   then every line is filled from min to max with the face's MC pattern
;   (masked partial bytes at both ends, whole bytes in between)
; - opposite faces share a colour, so the 3 visible faces always differ
; - rotation + perspective of the 8 corners and the back-face test are
;   precalculated at assemble time (128 steps), the drawing is all run time
; Docs: docs/08-effects-library.md (C8)
; Based on: codebase64 base:filling_the_vectors (span filling idea), rewritten
; Limitations: precalculated rotation (no run-time 3D maths); small canvas;
; no edge-sharing rule, so 1 pixel of a face may overlap its neighbour.
; =============================================================================
!source "c64.asm"

BUF_A   = $2000
BUF_B   = $2800
CANVAS  = 128                   ; offset of char 16 (chars 0-15: char 0 blank)
SCR_COL = 12                    ; canvas position on screen
SCR_ROW = 5
STEPS   = 128
ZC      = 4.5                   ; camera distance (cube corners at +-1)
PI      = 3.14159265

zp_ptr  = $20                   ; 2 bytes, column pointer
zp_vp   = $22                   ; 2 bytes, X table pointer
zp_vp2  = $24                   ; 2 bytes, Y table pointer
zp_step = $26
zp_vis  = $27
zp_face = $28
zp_xa   = $29
zp_ya   = $2a
zp_xb   = $2b
zp_yb   = $2c
zp_dl   = $2d                   ; 16-bit dividend / slope
zp_dh   = $2e
zp_dy   = $2f
zp_x8   = $30                   ; 2 bytes, 8.8 x
zp_neg  = $32
zp_ymin = $33
zp_ymax = $34
zp_pat  = $35
zp_c0   = $36
zp_c1   = $37
zp_mask = $38
zp_y    = $39
zp_tmp  = $3a
zp_bufhi = $3b                  ; 0 = drawing into A, 8 = into B
zp_fb   = $3c                   ; face * 4
zp_ei   = $3d                   ; edge index
zp_x0   = $3e
zp_x1   = $3f

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #YELLOW             ; MC 01
        sta BGCOLOR1
        lda #ORANGE             ; MC 10
        sta BGCOLOR2
        lda #$08+RED            ; MC 11 = colour RAM (bit 3 = multicolour)
        +fill_1000 COLOR_RAM
        lda #0
        +fill_1000 SCREEN
        tax                     ; clear both charsets
-       !for p, 0, 15 { sta BUF_A + p * $100, x }
        inx
        bne -
        lda #<(SCREEN + SCR_ROW * 40 + SCR_COL)
        sta zp_ptr
        lda #>(SCREEN + SCR_ROW * 40 + SCR_COL)
        sta zp_ptr+1
        ldx #0                  ; canvas row r: chars 16 + r + c*15
.row:   ldy #0
        txa
        clc
        adc #16
-       sta (zp_ptr),y
        clc
        adc #15
        iny
        cpy #16
        bne -
        lda zp_ptr
        clc
        adc #40
        sta zp_ptr
        bcc +
        inc zp_ptr+1
+       inx
        cpx #15
        bne .row
        lda #$18                ; MC, 40 columns
        sta VIC_CTRL2
        lda #$1b
        sta VIC_CTRL1
        lda #$18                ; screen $0400, charset A
        sta VIC_MEMPTR
        lda #8                  ; draw into B first
        sta zp_bufhi
        lda #0
        sta zp_step
        sta want
        +set_irq irq, $fc
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   jsr draw_frame
        lda zp_bufhi            ; show what we just drew
        beq +
        lda #$1a                ; charset B
        !byte $2c               ; bit abs: skip next lda
+       lda #$18                ; charset A
        sta want
-       lda want                ; wait until the IRQ has flipped
        bne -
        lda zp_bufhi
        eor #8
        sta zp_bufhi
        inc zp_step
        lda zp_step
        and #STEPS-1
        sta zp_step
        jmp main

irq:    +irq_enter
        lda want
        beq +
        sta VIC_MEMPTR
        lda #0
        sta want
+       +irq_exit

nmi:    rti
want:   !byte 0

; ---- one frame: clear, fetch corners, draw the visible faces ------------------
!macro clear .buf {
        ldx #119
        lda #0
-       !for c, 0, 15 { sta .buf + CANVAS + c * 120, x }
        dex
        bpl -
}
draw_frame:
        lda zp_bufhi
        bne +
        +clear BUF_A
        jmp ++
+       +clear BUF_B
++      lda zp_step             ; corner tables: step*8
        asl
        asl
        asl
        sta zp_vp
        sta zp_vp2
        lda zp_step
        lsr
        lsr
        lsr
        lsr
        lsr
        clc
        adc #>vtabx
        sta zp_vp+1
        adc #4                  ; vtaby = vtabx + $400
        sta zp_vp2+1
        ldy #7
-       lda (zp_vp),y
        sta px,y
        lda (zp_vp2),y
        sta py,y
        dey
        bpl -
        ldx zp_step
        lda vistab,x
        sta zp_vis
        lda #0
        sta zp_face
.face:  ldx zp_face
        lda bitval,x
        and zp_vis
        bne +
        jmp .next               ; face turned away
+       lda facepat,x
        sta zp_pat
        txa
        asl
        asl
        sta zp_fb
        lda #$ff                ; y range of the face
        sta zp_ymin
        lda #0
        sta zp_ymax
        ldy #3
-       tya
        ora zp_fb
        tax
        lda facev,x
        tax
        lda py,x
        cmp zp_ymin
        bcs +
        sta zp_ymin
+       cmp zp_ymax
        bcc +
        sta zp_ymax
+       dey
        bpl -
        ldy zp_ymin             ; empty spans
-       lda #$ff
        sta minx,y
        lda #0
        sta maxx,y
        cpy zp_ymax
        iny
        bcc -
        lda #0
        sta zp_ei
.edge:  lda zp_ei
        ora zp_fb
        tay
        ldx facev,y
        lda px,x
        sta zp_xa
        lda py,x
        sta zp_ya
        lda zp_ei
        clc
        adc #1
        and #3
        ora zp_fb
        tay
        ldx facev,y
        lda px,x
        sta zp_xb
        lda py,x
        sta zp_yb
        jsr edge
        inc zp_ei
        lda zp_ei
        cmp #4
        bne .edge
        ldy zp_ymin             ; fill
-       sty zp_y
        lda minx,y
        sta zp_x0
        lda maxx,y
        sta zp_x1
        jsr span
        ldy zp_y
        cpy zp_ymax
        iny
        bcc -
.next:  inc zp_face
        lda zp_face
        cmp #6
        beq +
        jmp .face
+       rts

; ---- walk one edge, widen minx/maxx ------------------------------------------
edge:
        lda zp_ya
        cmp zp_yb
        bcc .down
        bne .swap
        ldy zp_ya               ; horizontal: just the two end points
        lda zp_xa
        jsr .mm
        lda zp_xb
        jmp .mm
.swap:  ldx zp_xa
        ldy zp_ya
        lda zp_xb
        sta zp_xa
        lda zp_yb
        sta zp_ya
        stx zp_xb
        sty zp_yb
.down:  lda zp_yb
        sec
        sbc zp_ya
        sta zp_dy
        lda zp_xb
        sec
        sbc zp_xa
        sta zp_neg              ; bit 7 = sign of dx
        bpl +
        eor #$ff
        clc
        adc #1
+       sta zp_dh               ; |dx| * 256 / dy
        lda #0
        sta zp_dl
        ldx #16
-       asl zp_dl
        rol zp_dh
        rol
        cmp zp_dy
        bcc +
        sbc zp_dy
        inc zp_dl
+       dex
        bne -
        bit zp_neg
        bpl +
        lda #0
        sec
        sbc zp_dl
        sta zp_dl
        lda #0
        sbc zp_dh
        sta zp_dh
+       lda #$80
        sta zp_x8
        lda zp_xa
        sta zp_x8+1
        ldy zp_ya
-       lda zp_x8+1
        jsr .mm
        lda zp_x8
        clc
        adc zp_dl
        sta zp_x8
        lda zp_x8+1
        adc zp_dh
        sta zp_x8+1
        cpy zp_yb
        iny
        bcc -
        rts
.mm:    cmp minx,y
        bcs +
        sta minx,y
+       cmp maxx,y
        bcc +
        sta maxx,y
+       rts

; ---- fill line zp_y from x0 to x1 (MC pixels) with zp_pat ----------------------
span:
        ldx zp_x0
        lda lmask,x
        sta zp_mask
        lda colof,x
        sta zp_c0
        ldx zp_x1
        lda colof,x
        sta zp_c1
        cmp zp_c0
        bne .multi
        lda rmask,x
        and zp_mask
        sta zp_mask
        ldx zp_c0
        jmp put_masked
.multi: ldx zp_c0
        jsr put_masked
        ldx zp_x1
        lda rmask,x
        sta zp_mask
        ldx zp_c0
-       inx
        cpx zp_c1
        bne +
        jmp put_masked          ; last (partial) byte
+       lda colhi,x             ; whole byte
        clc
        adc zp_bufhi
        sta zp_ptr+1
        lda collo,x
        sta zp_ptr
        ldy zp_y
        lda zp_pat
        sta (zp_ptr),y
        jmp -
put_masked:                     ; column X: keep ~mask, put pat & mask
        lda colhi,x
        clc
        adc zp_bufhi
        sta zp_ptr+1
        lda collo,x
        sta zp_ptr
        ldy zp_y
        lda zp_mask
        eor #$ff
        and (zp_ptr),y
        sta zp_tmp
        lda zp_pat
        and zp_mask
        ora zp_tmp
        sta (zp_ptr),y
        rts

; ---- tables -------------------------------------------------------------------
bitval:  !byte 1, 2, 4, 8, 16, 32
facepat: !byte $55, $55, $aa, $aa, $ff, $ff
facev:   !byte 0, 2, 6, 4,  1, 3, 7, 5      ; x = -1, +1
         !byte 0, 1, 5, 4,  2, 3, 7, 6      ; y = -1, +1
         !byte 0, 1, 3, 2,  4, 5, 7, 6      ; z = -1, +1
collo:   !for c, 0, 15 { !byte <(BUF_A + CANVAS + c * 120) }
colhi:   !for c, 0, 15 { !byte >(BUF_A + CANVAS + c * 120) }
colof:   !for x, 0, 63 { !byte x >> 2 }
lmask:   !for x, 0, 63 { !byte $ff >> (2 * (x & 3)) }
rmask:   !for x, 0, 63 { !byte ($ff << (6 - 2 * (x & 3))) & $ff }
px:      !fill 8, 0
py:      !fill 8, 0
minx:    !fill 120, 0
maxx:    !fill 120, 0

; ---- assemble-time 3D: rotate around Y by a, then X by b -> rx, ry, rz --------
!macro rot .x, .y, .z, .a, .b {
        !set rx = .x * cos(.a) + .z * sin(.a)
        !set z1 = .z * cos(.a) - .x * sin(.a)
        !set ry = .y * cos(.b) - z1 * sin(.b)
        !set rz = .y * sin(.b) + z1 * cos(.b)
}
!macro corner .s, .v, .wanty {
        +rot float((.v & 1) * 2 - 1), float(((.v >> 1) & 1) * 2 - 1), float(((.v >> 2) & 1) * 2 - 1), .s * 2 * PI / STEPS, .s * 2 * PI / (STEPS / 2)
        !if .wanty { !byte int(60.5 + 90 * ry / (rz + ZC)) } else { !byte int(32.5 + 45 * rx / (rz + ZC)) }
}
!macro facebit .s, .f, .nx, .ny, .nz {
        +rot float(.nx), float(.ny), float(.nz), .s * 2 * PI / STEPS, .s * 2 * PI / (STEPS / 2)
        !if rz < -1 / ZC { !set m = m | (1 << .f) }
}
vistab:
!for s, 0, STEPS - 1 {
        !set m = 0
        +facebit s, 0, -1, 0, 0
        +facebit s, 1, 1, 0, 0
        +facebit s, 2, 0, -1, 0
        +facebit s, 3, 0, 1, 0
        +facebit s, 4, 0, 0, -1
        +facebit s, 5, 0, 0, 1
        !byte m
}
        !align 255, 0
vtabx:  !for s, 0, STEPS - 1 { !for v, 0, 7 { +corner s, v, 0 } }
vtaby:  !for s, 0, STEPS - 1 { !for v, 0, 7 { +corner s, v, 1 } }
!if * > BUF_A { !error "code/tables run into the charsets" }
