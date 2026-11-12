; =============================================================================
; A12_char_animation.asm - A12 Char animation
; What you see: a building with blinking windows and a waving flag, rain
; falling in the sky, and waves flowing on the water at the bottom.
; Technique:
; - the ROM font is copied to a RAM charset ($2000), then 5 chars ($60-$64)
;   are redefined. Every cell using a char changes when its 8 bytes change
; - water: ROL each of the 8 bytes (bit 7 back into bit 0) -> moves sideways
; - rain : rotate the 8 bytes down (byte 7 -> byte 0) -> falls
; - flag : copy one of 4 frames (made at assemble time with sin()) every 5 frames
; - window: swap between "lit" and "dark" bytes every 32 frames
; Docs: docs/08-effects-library.md (A12)
; =============================================================================
!source "c64.asm"

CHARSET   = $2000               ; VIC bank 0, outside the char ROM shadow
CH_WATER  = $60
CH_RAIN   = $61
CH_FLAG   = $62
CH_WINDOW = $63
CH_POLE   = $64
CHR       = CHARSET + $60*8     ; first redefined char
WATER_ROW = 21
BLD_COL   = 6                   ; building: columns 6-15, rows 11-20
BLD_TOP   = 11

zp_ptr     = $20
frame      = $22
frame_flag = $23
flag_frame = $24

        +basic_upstart

start:
        +demo_init nmi
        jsr copy_rom_font       ; IRQs still off here
        ldx #5*8-1              ; our 5 chars
-       lda tiles,x
        sta CHR,x
        dex
        bpl -

        lda #BLACK
        sta BORDER
        lda #BLUE
        sta BACKGROUND
        lda #$18                ; screen $0400, charset $2000
        sta VIC_MEMPTR
        jsr draw_scene

        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_frame, $fc
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag
        beq main
        lda #0
        sta frame_flag
        inc frame
        jsr animate
        jmp main

irq_frame:
        +irq_enter
        inc frame_flag
        +irq_exit

; ---- rewrite the char bytes ------------------------------------------------
animate:
        ldx #7                  ; water: each byte rotated left by 1 pixel
-       lda CHR+(CH_WATER-$60)*8,x
        asl                     ; bit 7 -> carry
        adc #0                  ; carry -> bit 0
        sta CHR+(CH_WATER-$60)*8,x
        dex
        bpl -

        lda frame               ; rain: one pixel down every 2nd frame
        lsr
        bcc +
        ldy CHR+(CH_RAIN-$60)*8+7
        ldx #6
-       lda CHR+(CH_RAIN-$60)*8,x
        sta CHR+(CH_RAIN-$60)*8+1,x
        dex
        bpl -
        sty CHR+(CH_RAIN-$60)*8
+
        lda frame               ; flag: next frame every 5 frames
-       sec                     ; A = frame mod 5 (crude, fine for 8 bits)
        sbc #5
        bcs -
        adc #5
        bne +
        lda flag_frame
        clc
        adc #8
        and #31
        sta flag_frame
        tax
        ldy #0
-       lda flag_frames,x
        sta CHR+(CH_FLAG-$60)*8,y
        inx
        iny
        cpy #8
        bne -
+
        lda frame               ; windows: toggle every 32 frames
        and #31
        bne +
        ldx #7
-       lda CHR+(CH_WINDOW-$60)*8,x
        eor #%01111110          ; flip the inside of the window
        sta CHR+(CH_WINDOW-$60)*8,x
        dex
        bpl -
+       rts

; ---- static scene ----------------------------------------------------------
draw_scene:
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM
        ldx #title_end-title-1  ; title
-       lda title,x
        sta SCREEN+40+2,x
        lda #WHITE
        sta COLOR_RAM+40+2,x
        dex
        bpl -
        ldx #0                  ; rain: every 7th cell of rows 3-20
-       lda #CH_RAIN
        sta SCREEN+3*40,x
        sta SCREEN+3*40+$100,x
        txa
        clc
        adc #7
        tax
        cpx #252                ; stop before wrapping (36 drops per page)
        bcc -
        !for r, 0, 9 {          ; building: windows on a solid body
        ldx #9
-       txa
        and #1
        bne +
        lda #CH_WINDOW
        sta SCREEN+(BLD_TOP+r)*40+BLD_COL,x
        lda #YELLOW
        bne ++
+       lda #$a0                ; solid block (reverse space)
        sta SCREEN+(BLD_TOP+r)*40+BLD_COL,x
        lda #DARK_GREY
++      sta COLOR_RAM+(BLD_TOP+r)*40+BLD_COL,x
        dex
        bpl -
        }
        lda #CH_POLE            ; flag pole and flag on the roof
        sta SCREEN+(BLD_TOP-1)*40+BLD_COL+4
        sta SCREEN+(BLD_TOP-2)*40+BLD_COL+4
        lda #CH_FLAG
        sta SCREEN+(BLD_TOP-2)*40+BLD_COL+5
        lda #LIGHT_GREY
        sta COLOR_RAM+(BLD_TOP-1)*40+BLD_COL+4
        sta COLOR_RAM+(BLD_TOP-2)*40+BLD_COL+4
        lda #RED
        sta COLOR_RAM+(BLD_TOP-2)*40+BLD_COL+5
        ldx #39                 ; water, rows 21-24
-       lda #CH_WATER
        !for r, 0, 3 {
        sta SCREEN+(WATER_ROW+r)*40,x
        }
        lda #CYAN
        sta COLOR_RAM+WATER_ROW*40,x
        sta COLOR_RAM+(WATER_ROW+2)*40,x
        lda #WHITE
        sta COLOR_RAM+(WATER_ROW+1)*40,x
        sta COLOR_RAM+(WATER_ROW+3)*40,x
        dex
        bpl -
        rts

; ROM font (lower/upper case set at $d800 in the char ROM) -> CHARSET
copy_rom_font:
        lda #$33                ; char ROM visible at $d000, I/O hidden
        sta CPU_PORT
        ldx #0
-       !for p, 0, 7 {
        lda $d800+p*$100,x
        sta CHARSET+p*$100,x
        }
        inx
        bne -
        lda #BANK_IO_ONLY
        sta CPU_PORT
        rts

nmi:    rti

title:  !scr "A12 char animation: 5 chars, 40 bytes"
title_end:

tiles:  ; $60 water, $61 rain, $62 flag (frame 0), $63 window, $64 pole
        !byte %00000000, %00000000, %00011000, %01100110
        !byte %10000001, %00000000, %00000000, %00000000
        !byte %00000000, %00010000, %00010000, %00000000
        !byte %00000000, %00000000, %00000000, %00000000
        !fill 8, 0
        !byte %00000000, %01111110, %01111110, %01111110
        !byte %01111110, %01111110, %01111110, %00000000
        !fill 8, %00000011

; 4 flag frames: 8 columns, each column = 5 pixels high, shifted down by
; 0..3 pixels following a sine (the wave travels 2 columns per frame)
flag_frames:
        !for k, 0, 3 {
        !for y, 0, 7 {
        !set bits = 0
        !for x, 0, 7 {
        !set off = int(1.5 + 1.5 * sin((x + k * 2) * 3.14159265 / 4))
        !if y >= off {
        !if y < off + 5 {
        !set bits = bits | (128 >> x)
        }
        }
        }
        !byte bits
        }
        }
