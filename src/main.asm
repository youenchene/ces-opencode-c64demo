; =============================================================================
; opencode-c64 - main demo, made for Codeurs en Seine 2026 (Rouen, Kindarena, 19.11.2026)
;
; One screen: Codeurs en Seine. Copper bars and scroller stay on screen.
;
;   D07 part "ces"     rows  1-11 : D03 Codeurs en Seine logo (custom charset A), shine sweep
;                      row  12    : "rouen * kindarena * 19.11.2026"
;                      rows 14-23 : D04 Rouen skyline (custom charset B), water shimmer
;   always             top border : D01 stable raster "copper" bars (irq_bars1/irq_bars2)
;                      row  24    : D02 1x1 smooth scroller (irq_split/irq_bottom)
; Effect references: docs/08-effects-library.md
;
; Charset split: charset A above row 13, charset B from row 13 down (irq_mid). Both hold the
; ROM font in codes $00-$5f, so text renders the same in either. Keep row 13 free of graphics.
;
; Build:  make          -> build/opencode.prg
;         make d64      -> build/opencode.d64 (for real hardware)
;         make run      -> launch in VICE (x64sc)
;         make gfx      -> regenerate src/gfx/*.asm from assets/
; Music:  src/music/music.sid at $1000 (Teh Disco by Jammer), on by default when the file exists.
;         make MUSIC=0 to build without it, make TIMING=1 to see its CPU cost (docs/05-music.md)
;
; Architecture notes and memory map: docs/06-demo-plan.md
; =============================================================================
!source "c64.asm"
!source "src/gfx/ces_logo.inc.asm"     ; generated: ces_logo_W/_H
!source "src/gfx/rouen.inc.asm"        ; generated: rouen_W/_H

!ifndef MUSIC { MUSIC = 0 }
!ifndef TIMING { TIMING = 0 }

; ---- memory map ----------------------------------------------------------------
CODE_END     = $1000            ; code must stay below (music / free)
MUSIC_INIT   = $1000
MUSIC_PLAY   = $1003
CHARSET_A    = $2000            ; top half of the screen
CHARSET_B    = $2800            ; bottom half of the screen
FIRST_TILE   = $60              ; codes below are copied from the ROM font (see tools/img2chars.py)
DATA_START   = $3000
MEMPTR_A     = $18              ; $d018: screen $0400, charset $2000
MEMPTR_B     = $1a              ; $d018: screen $0400, charset $2800

; ---- zero page ---------------------------------------------------------------
; $20-$2d: kept away from $f0-$ff, which most SID players use (Teh Disco: $fb/$fc)
zp_scroll   = $20               ; 2 bytes: scroll text pointer
zp_src      = $2a               ; 2 bytes: blit source
zp_dst      = $2c               ; 2 bytes: blit destination

; ---- layout -------------------------------------------------------------------
SCROLL_ROW   = 24
SCROLL_ADDR  = SCREEN + SCROLL_ROW*40

CES_ROW      = 1
CES_COL      = (40 - ces_logo_W) / 2
DATE_ROW     = 12
ROUEN_ROW    = 14               ; skyline rows 14-22, water row 23
WATER_ROW    = ROUEN_ROW + rouen_H - 1

; ---- raster lines --------------------------------------------------------------
BAR_LINE     = $10              ; stable bars start at BAR_LINE+2, in the top border
BAR_COUNT    = 32
MID_LINE     = $9d              ; inside row 13 (lines $9b-$a2): switch to charset B
SPLIT_LINE   = $f0              ; just above scroller row (row 24 starts at $f3)
BOTTOM_LINE  = $fc              ; below the last text row

; copy a .w x .h map to screen position (.col, .row)
!macro blit .map, .col, .row, .w, .h {
        lda #<.map
        sta zp_src
        lda #>.map
        sta zp_src+1
        lda #<(SCREEN + .row*40 + .col)
        sta zp_dst
        lda #>(SCREEN + .row*40 + .col)
        sta zp_dst+1
        lda #.w
        sta blit_w
        lda #.h
        sta blit_h
        jsr blit
}

; =============================================================================
        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        jsr copy_rom_font       ; needs IRQs off (banks I/O out for a moment)
        lda #MEMPTR_A
        sta VIC_MEMPTR
        lda #$c8
        sta VIC_CTRL2
        lda #$20
        +fill_1000 SCREEN

        jsr scroller_init
        jsr part_ces

!if MUSIC {
        lda #0
        jsr MUSIC_INIT
}

        lda #$1b                ; DEN on, 25 rows, yscroll 3, raster MSB 0
        sta VIC_CTRL1
        +set_irq irq_bars1, BAR_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

; ---- main loop: runs once per frame, after irq_bottom -------------------------
main_loop:
        lda frame_flag
        beq main_loop
        lda #0
        sta frame_flag
        inc frame

        jsr rotate_bars
        jsr scroller_update     ; must run between $fc and $f0 (it does)
        jsr ces_update
        jmp main_loop

nmi:    rti

; =============================================================================
; Codeurs en Seine screen
; =============================================================================

part_ces:                       ; D07
        lda #BLACK
        jsr clear_top
        +blit ces_logo_map, CES_COL, CES_ROW, ces_logo_W, ces_logo_H
        +blit rouen_map, 0, ROUEN_ROW, rouen_W, rouen_H
        ldx #0
-       lda date_text,x
        beq +
        sta SCREEN+DATE_ROW*40+(40-DATE_LEN)/2,x
        lda #YELLOW
        sta COLOR_RAM+DATE_ROW*40+(40-DATE_LEN)/2,x
        inx
        bne -
+       ldx #39                 ; skyline colours, one per column
-       lda rouen_colors,x
        !for r, 0, rouen_H - 2 {
        sta COLOR_RAM+(ROUEN_ROW+r)*40,x
        }
        dex
        bpl -
        rts

ces_update:
        jsr ces_shine
        jmp water_colors

; =============================================================================
; IRQ handlers
; =============================================================================

; ---- D04: switch to charset B (row 13 holds text only) ------------------------
irq_mid:
        +irq_enter
        lda #MEMPTR_B
        sta VIC_MEMPTR
        +set_irq irq_split, SPLIT_LINE
        +irq_exit

; ---- D02: apply fine scroll for the scroller row -----------------------------
irq_split:
        +irq_enter
        lda scroll_x            ; bit3=0 -> 38 columns, hides edge chars
        sta VIC_CTRL2
        +set_irq irq_bottom, BOTTOM_LINE
        +irq_exit

; ---- bottom: restore screen, music, signal main loop --------------------------
irq_bottom:
        +irq_enter
        lda #$c8
        sta VIC_CTRL2
        lda #MEMPTR_A
        sta VIC_MEMPTR
!if MUSIC {
  !if TIMING {
        lda #WHITE              ; make TIMING=1: border shows the player's cost in raster lines
        sta BORDER
  }
        jsr MUSIC_PLAY
  !if TIMING {
        lda #BLACK
        sta BORDER
  }
}
        inc frame_flag
        +set_irq irq_bars1, BAR_LINE
        +irq_exit

; ---- D01: stable raster bars (double IRQ), must not cross a page --------------
        !align 255, 0
irq_bars1:
        sta save_a
        stx save_x
        sty save_y
        lda #<irq_bars2
        sta IRQ_VECTOR
        lda #>irq_bars2
        sta IRQ_VECTOR+1
        inc VIC_RASTER
        asl VIC_IRQ_STATUS
        tsx
        cli
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
irq_bars2:
        txs
        ldx #$08
-       dex
        bne -
        bit $00
        lda VIC_RASTER
        cmp VIC_RASTER
        beq +
+       ldx #0                  ; ---- cycle exact from here, 63 cycles/line
.bar:   lda bars,x              ; 4
        sta BORDER              ; 4
        ldy #9                  ; 2
-       dey                     ; 44
        bne -
        nop                     ; 2
        inx                     ; 2
        cpx #BAR_COUNT          ; 2
        bne .bar                ; 3  = 63
        lda #BLACK
        sta BORDER

        lda #<irq_mid
        sta IRQ_VECTOR
        lda #>irq_mid
        sta IRQ_VECTOR+1
        lda #MID_LINE
        sta VIC_RASTER
        asl VIC_IRQ_STATUS
        lda save_a
        ldx save_x
        ldy save_y
        rti

save_a: !byte 0
save_x: !byte 0
save_y: !byte 0

; =============================================================================
; Helpers
; =============================================================================

; ROM font codes $00-$5f (lower/upper case set at $d800) -> both charsets.
copy_rom_font:
        lda #$33                ; char ROM visible at $d000, I/O hidden
        sta CPU_PORT
        ldx #0
-       !for p, 0, 2 {
        lda $d800+p*$100,x
        sta CHARSET_A+p*$100,x
        sta CHARSET_B+p*$100,x
        }
        inx
        bne -
        lda #BANK_IO_ONLY
        sta CPU_PORT
        rts

; clear rows 0-23 (960 bytes; scroller row untouched), colour RAM = A
clear_top:
        ldx #0
-       sta COLOR_RAM,x
        sta COLOR_RAM+$100,x
        sta COLOR_RAM+$200,x
        sta COLOR_RAM+$2c0,x    ; overlaps, ends exactly at +959
        inx
        bne -
        lda #$20
-       sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$2c0,x
        inx
        bne -
        rts

; zp_src (blit_w x blit_h map) -> zp_dst (screen, 40 per row)
blit:
.row:   ldy blit_w
        dey
-       lda (zp_src),y
        sta (zp_dst),y
        dey
        bpl -
        lda zp_src
        clc
        adc blit_w
        sta zp_src
        bcc +
        inc zp_src+1
+       lda zp_dst
        clc
        adc #40
        sta zp_dst
        bcc +
        inc zp_dst+1
+       dec blit_h
        bne .row
        rts

; =============================================================================
; Effects
; =============================================================================

rotate_bars:                    ; D01
        lda bars
        pha
        ldx #0
-       lda bars+1,x
        sta bars,x
        inx
        cpx #BAR_COUNT-1
        bne -
        pla
        sta bars+BAR_COUNT-1
        rts

; ---- D03: diagonal shine sweeping across the Codeurs en Seine logo ---------------
ces_shine:
        dec shine_phase
        ldx #ces_logo_W-1
-       txa
        clc
        adc shine_phase
        sta tmp
        !for r, 0, ces_logo_H - 1 {
        lda tmp
        clc
        adc #r
        and #63
        tay
        lda shine_gradient,y
        sta COLOR_RAM+(CES_ROW+r)*40+CES_COL,x
        }
        dex
        bmi +
        jmp -                   ; unrolled body is too long for a branch
+       rts

; ---- D04: colour waves flowing along the Seine -----------------------------------
water_colors:
        lda frame
        and #1
        bne +
        inc water_phase
+       ldx #39
-       txa
        clc
        adc water_phase
        and #15
        tay
        lda water_gradient,y
        sta COLOR_RAM+WATER_ROW*40,x
        dex
        bpl -
        rts

; ---- D02 smooth scroller --------------------------------------------------------
scroller_init:
        lda #<scroll_text
        sta zp_scroll
        lda #>scroll_text
        sta zp_scroll+1
        ldx #39
        lda #YELLOW
-       sta COLOR_RAM+SCROLL_ROW*40,x
        dex
        bpl -
        rts

scroller_update:
        lda scroll_x
        sec
        sbc #1
        and #$07
        sta scroll_x
        bcs .sdone
        ldx #0
-       lda SCROLL_ADDR+1,x
        sta SCROLL_ADDR,x
        inx
        cpx #39
        bne -
        ldy #0
        lda (zp_scroll),y
        bne +
        lda #<scroll_text
        sta zp_scroll
        lda #>scroll_text
        sta zp_scroll+1
        lda (zp_scroll),y
+       sta SCROLL_ADDR+39
        inc zp_scroll
        bne .sdone
        inc zp_scroll+1
.sdone: rts

!if * > CODE_END { !error "code reaches $1000 (music area): move data after DATA_START" }

; =============================================================================
; Music, charsets
; =============================================================================
!if MUSIC {
        * = MUSIC_INIT
        !bin "src/music/music.sid", , $7e  ; skip PSID v2 header ($7c) + load address (2)
        !if * > CHARSET_A { !error "music overlaps charset A at $2000" }
}

        * = CHARSET_A + FIRST_TILE*8
        !source "src/gfx/ces_logo.chars.asm"
        * = CHARSET_B + FIRST_TILE*8
        !source "src/gfx/rouen.chars.asm"

; =============================================================================
; Data
; =============================================================================
        * = DATA_START

bars:   ; 32 lines, rotated every frame. DATA_START is page aligned: lda bars,x never crosses
        !byte $06,$0e,$03,$01,$03,$0e,$06,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00
        !byte $09,$08,$0a,$07,$01,$07,$0a,$08
        !byte $09,$00,$00,$00,$00,$00,$00,$00

frame:        !byte 0
frame_flag:   !byte 0
tmp:          !byte 0
blit_w:       !byte 0
blit_h:       !byte 0
shine_phase:  !byte 0
water_phase:  !byte 0
scroll_x:     !byte 7

shine_gradient: ; 64 entries: light blue logo with a white glint passing through
        !fill 40, LIGHT_BLUE
        !byte CYAN, CYAN, WHITE, WHITE, WHITE, WHITE, CYAN, CYAN
        !fill 16, LIGHT_BLUE

water_gradient: ; 16 entries
        !byte BLUE, BLUE, BLUE, LIGHT_BLUE, LIGHT_BLUE, CYAN, WHITE, CYAN
        !byte LIGHT_BLUE, LIGHT_BLUE, BLUE, BLUE, BLUE, BLUE, BLUE, BLUE

rouen_colors: ; one colour per column for the skyline rows
        !fill 13, GREY          ; pont Gustave-Flaubert
        !fill 3, LIGHT_BLUE     ; houses
        !fill 10, WHITE         ; cathedrale Notre-Dame
        !fill 2, LIGHT_BLUE     ; houses
        !fill 5, LIGHT_GREY     ; abbatiale Saint-Ouen
        !fill 7, LIGHT_BLUE     ; houses

date_text:
        !scr "rouen * kindarena * 19.11.2026"
DATE_LEN = * - date_text
        !byte 0

!source "src/gfx/ces_logo.map.asm"
!source "src/gfx/rouen.map.asm"

; Texts: avoid '@' (screen code 0 = terminator) and "{|}~" (codes $5b-$5e)
scroll_text:
        !scr "      *** opencode on the commodore 64 ***    "
        !scr "live at codeurs en seine 2026, kindarena, rouen ...    "
        !scr "an AI coding agent wrote this demo in 6502 assembly ...    "
        !scr "stable raster bars, smooth scroller, custom charsets, colour cycling, all at 50 fps on a real 1 mhz machine ...    "
        !scr "try it: opencode.ai ...    greetings to all codeuses & codeurs, and to all sceners!          "
        !byte 0
