; =============================================================================
; B30_rotating_heads.asm - B30 Bouncing portrait sprites
; Two cutout portraits spin in the plane of the screen and bounce independently
; off all four edges of the 320x200 display.
; Each portrait uses four double-size hires sprites in a 96x84 rectangle.
; Position updates at 50 Hz; pointers advance one pose every four frames.
; Limitations: collisions use the sprite rectangle; the portraits pass through
; each other. All eight hardware sprites are used.
; Docs: docs/08-effects-library.md (B30)
; =============================================================================
!source "c64.asm"

SPRITE_DATA = $2000
SPRITE_PTRS = SCREEN + $3f8
LEFT        = 24
TOP         = 50
SPR_W       = 48                 ; one sprite, expanded in X and Y
SPR_H       = 42
WIDTH       = 2*SPR_W
HEIGHT      = 2*SPR_H
MAX_X       = 320-WIDTH           ; coordinates relative to the display
MAX_Y       = 200-HEIGHT

        +basic_upstart

start:
        +demo_init nmi
        lda CIA2_PRA
        ora #3
        sta CIA2_PRA              ; VIC bank 0
        lda #DARK_GREY
        sta BORDER
        lda #BLACK
        sta BACKGROUND
        sta SPR_ENABLE
        sta SPR_MULTICOLOR
        sta SPR_PRIORITY
        lda #$14
        sta VIC_MEMPTR
        lda #$08
        sta VIC_CTRL2
        lda #$1b
        sta VIC_CTRL1
        lda #$20
        +fill_1000 SCREEN
        ldx #3
-       lda #WHITE
        sta SPR0_COLOR,x
        lda #CYAN
        sta SPR0_COLOR+4,x
        dex
        bpl -
        jsr draw_heads
        lda #$ff
        sta SPR_EXPAND_X
        sta SPR_EXPAND_Y
        sta SPR_ENABLE

main:
-       lda VIC_RASTER
        cmp #$fc                 ; all eight sprites have finished drawing
        bne -
        inc frame
        ldx #1
-       jsr move_head
        dex
        bpl -
        jsr draw_heads
        jmp main

; Signed velocity, added to unsigned coordinates. Clamp and reverse at either
; edge so a larger velocity can never carry a sprite outside the display.
move_head:
        ldy #0
        lda vx,x
        bpl +
        dey
+       clc
        adc xpos_lo,x
        sta xpos_lo,x
        tya
        adc xpos_hi,x
        sta xpos_hi,x
        bmi .left
        cmp #>MAX_X
        bcc .move_y
        bne .right
        lda xpos_lo,x
        cmp #<MAX_X
        bcc .move_y
.right: lda #>MAX_X
        ldy #<MAX_X
        bne .turn_x
.left:  lda #0
        tay
.turn_x:
        sta xpos_hi,x
        tya
        sta xpos_lo,x
        lda #0
        sec
        sbc vx,x
        sta vx,x

.move_y:
        lda vy,x
        bmi .up
        clc
        adc ypos,x
        cmp #MAX_Y
        bcc .store_y
        lda #MAX_Y
        bcs .turn_y
.up:    clc
        adc ypos,x
        bcs .store_y
        lda #0
.turn_y:
        tay
        lda #0
        sec
        sbc vy,x
        sta vy,x
        tya
.store_y:
        sta ypos,x
        rts

draw_heads:
        lda #0
        sta msb
        ldx #0
.head:
        lda frame
        lsr
        lsr
        cpx #0
        beq +
        eor #$ff                 ; spin the other way
+       and #15
        asl
        asl
        clc
        adc sprite_base,x
        sta pose_ptr
        ldy first_sprite,x
        lda #0
        sta corner
.corner:
        lda pose_ptr
        sta SPRITE_PTRS,y
        inc pose_ptr
        tya
        asl
        tay
        stx head
        ldx corner
        lda corner_y,x
        ldx head
        clc
        adc ypos,x
        sta SPR0_Y,y
        ldx corner
        lda corner_x,x
        ldx head
        clc
        adc xpos_lo,x
        sta SPR0_X,y
        lda xpos_hi,x
        adc #0
        lsr                      ; ninth X bit -> carry
        ror msb                  ; sprites processed in order 0..7
        tya
        lsr
        tay
        iny
        inc corner
        lda corner
        cmp #4
        bne .corner
        inx
        cpx #2
        bne .head
        lda msb
        sta SPR_X_MSB
        rts

nmi:    rti

xpos_lo:      !byte 24, 184
xpos_hi:      !byte 0, 0
ypos:         !byte 18, 96
vx:           !byte 2, -2
vy:           !byte 1, -2
frame:        !byte 0
msb:          !byte 0
head:         !byte 0
corner:       !byte 0
pose_ptr:     !byte 0
first_sprite: !byte 0, 4
corner_x:     !byte LEFT, LEFT+SPR_W, LEFT, LEFT+SPR_W
corner_y:     !byte TOP, TOP, TOP+SPR_H, TOP+SPR_H
sprite_base:  !byte head0_sprites/64, head1_sprites/64

        * = SPRITE_DATA
        !source "src/gfx/heads.sprites.asm"
!if * > $4000 { !error "portrait sprites exceed VIC bank 0" }
