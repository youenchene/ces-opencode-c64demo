; =============================================================================
; C10_sprite_fpp.asm - C10 Sprite FPP (Y-expand flip-flop trick)
; What you see: a "C64" logo made of 3 X-expanded sprites that stretches,
; squashes and wobbles vertically, line by line, over 120 raster lines.
; How:
; - the VIC adds 3 to a sprite's row counter (MCBASE) at cycle 15 of a line
;   only if its Y-expand flip-flop is set; with $d017 on, the flip-flop is
;   inverted at cycle 55. Writing $d017 = 0 then $ff between cycles 16 and 54
;   sets it just before that inversion: at cycle 15 of the next line it is
;   clear, so the row counter does not move -> the sprite row is repeated
; - doing that on every line freezes each sprite on one row; the sprite
;   POINTER is fetched on every line, so changing it each line picks any
;   64-byte block: one block = one logo line -> free per-line line picking
; - sprites 0/1/2 start 0/1/2 lines above the region, so they freeze on
;   rows 0/1/2: one block holds the 3 slices (bytes 0-2, 3-5, 6-8) and all
;   3 sprites share the same pointer value (1 load, 3 stores per line)
; - no badlines: DEN is 0 during line $30 (badlines disabled for the
;   frame) and set to 1 at line $31 (the border still opens at $33); the loop polls $d012 once per line, the register
;   writes have a ~38 cycle window so no stable raster is needed
; - main loop: pointer table = logo row at 8.8 position, scale from a sine,
;   plus a per-line wave
; Docs: docs/08-effects-library.md (C10)
; Based on: codebase64 base:sprite_fpp / base:sprite-crunching (the VIC
;           flip-flop rules), rewritten
; Limitations: the true "sprite crunch" ($d017 cleared exactly at cycle 15,
; giving weird MCBASE jumps) is not shown; only 3 sprites (CPU budget).
; =============================================================================
!source "c64.asm"

R0      = $40                   ; first raster line of the region
H       = 120                   ; lines in the region
IRQ_LINE = $31                 ; after $30 (badline enable check), before $33
SPRITES = $2000                 ; block k = logo row k (k = 0..31), $2800 blank
PTR0    = SPRITES / 64
BLANK   = PTR0 + 32
X0      = 24 + (320 - 144) / 2

zp_t    = $20
zp_acc  = $21                   ; 2 bytes, 8.8 logo row
zp_sc   = $23                   ; 2 bytes, 8.8 rows per line
zp_w    = $25                   ; wave phase

        +basic_upstart

start:
        +demo_init nmi
        lda #$0b                ; DEN=0 at line $30: no badlines this frame
        sta VIC_CTRL1
        lda #BLUE
        sta BORDER
        lda #BLACK
        sta BACKGROUND
        lda #0
        sta $3fff               ; idle-state graphics byte (bank 0)
        lda #X0
        sta SPR0_X
        lda #X0+48
        sta SPR0_X+2
        lda #X0+96
        sta SPR0_X+4
        lda #R0                 ; frozen on row 0
        sta SPR0_Y
        lda #R0-1               ; row 1
        sta SPR0_Y+2
        lda #R0-2               ; row 2
        sta SPR0_Y+4
        lda #YELLOW
        sta SPR0_COLOR
        lda #LIGHT_GREEN
        sta SPR0_COLOR+1
        lda #CYAN
        sta SPR0_COLOR+2
        lda #$07
        sta SPR_EXPAND_X
        sta SPR_ENABLE
        lda #0
        sta SPR_X_MSB
        sta SPR_EXPAND_Y
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

; ---- pointer table for the next frame -----------------------------------------
compute:
        inc zp_t
        inc zp_w
        inc zp_w
        inc zp_w
        ldx zp_t
        lda scale_lo,x
        sta zp_sc
        lda scale_hi,x
        sta zp_sc+1
        lda #0                  ; acc = 16.0 - (H/2) * scale (centred)
        sta zp_acc
        lda #16
        sta zp_acc+1
        ldx #H/2
-       lda zp_acc
        sec
        sbc zp_sc
        sta zp_acc
        lda zp_acc+1
        sbc zp_sc+1
        sta zp_acc+1
        dex
        bne -
        ldx #0
.line:  lda zp_acc+1
        cmp #32                 ; also catches negative values ($80-$ff)
        bcc +
        lda #BLANK-PTR0
+       clc
        adc #PTR0
        sta ptrtab,x
        txa                     ; wave index = 4*line + phase
        asl
        asl
        adc zp_w
        tay
        lda wave,y              ; signed 8.8 fraction
        ldy #0
        cmp #$80
        bcc +
        dey
+       clc
        adc zp_sc
        sta .lo+1
        tya
        adc zp_sc+1
        tay
.lo:    lda #0
        clc
        adc zp_acc
        sta zp_acc
        tya
        adc zp_acc+1
        sta zp_acc+1
        inx
        cpx #H
        bne .line
        rts

nmi:    rti
frame_flag: !byte 0

; ---- raster loop: one pass per line, synced by polling $d012 ------------------
        !align 255, 0
irq:
        +irq_enter
        lda #$1b                ; DEN=1 after line $30 but before $33: the
        sta VIC_CTRL1           ; border opens, yet no badline is enabled
        lda #BLANK
        sta SCREEN+$3f8
        sta SCREEN+$3f9
        sta SCREEN+$3fa
        ldx #0
        ldy #R0
.wait:  cpy VIC_RASTER          ; 4  new line? (sprite DMA ends ~cycle 1)
        bne .wait               ; 3
        lda ptrtab,x            ; 4  block for the NEXT line (p-access at 58)
        sta SCREEN+$3f8         ; 4
        sta SCREEN+$3f9         ; 4
        sta SCREEN+$3fa         ; 4
        lda #$00                ; 2
        sta SPR_EXPAND_Y        ; 4  clear YE: flip-flops set   (cycle ~25-33)
        lda #$07                ; 2
        sta SPR_EXPAND_Y        ; 4  YE on: inverted at 55 -> no step at 15
        iny                     ; 2
        inx                     ; 2
        cpx #H                  ; 2
        bne .wait               ; 3  ~48 cycles max incl. poll, < 63-9 (DMA)
        lda #BLANK              ; let the sprites run out on an empty block
        sta SCREEN+$3f8
        sta SCREEN+$3f9
        sta SCREEN+$3fa
        lda #0
        sta SPR_EXPAND_Y
        lda #$0b                ; DEN=0 again before next frame's line $30
        sta VIC_CTRL1
        inc frame_flag
        +irq_exit

        !align 255, 0
ptrtab: !fill H, BLANK
        !align 255, 0
wave:   !for i, 0, 255 { !byte int(40 * sin(float(i) * 2 * 3.14159265 / 256)) & $ff }
scale_lo: !for i, 0, 255 { !byte <int(185 + 115 * sin(float(i) * 2 * 3.14159265 / 256)) }
scale_hi: !for i, 0, 255 { !byte >int(185 + 115 * sin(float(i) * 2 * 3.14159265 / 256)) }

; ---- sprite blocks: 6x8 letters scaled x4 -> 24x32 -----------------------------
!macro x4 .v {
        !set .e = 0
        !for .b, 0, 5 {
                !if (.v >> .b) & 1 { !set .e = .e | (15 << (4 * .b)) }
        }
        !byte (.e >> 16) & 255, (.e >> 8) & 255, .e & 255
}
; one letter row = 4 blocks; slice of sprite s at row s (bytes 3s..3s+2)
!macro row .c, .six, .four {
        !for .r, 0, 3 {
                +x4 .c
                +x4 .six
                +x4 .four
                !fill 64 - 9, 0
        }
}
        * = SPRITES
        +row %...####., %...####., %.....##.
        +row %..##..##, %..##...., %....###.
        +row %..##...., %..##...., %...####.
        +row %..##...., %..#####., %..##.##.
        +row %..##...., %..##..##, %..######
        +row %..##...., %..##..##, %.....##.
        +row %..##..##, %..##..##, %.....##.
        +row %...####., %...####., %.....##.
        !fill 64, 0             ; BLANK block
