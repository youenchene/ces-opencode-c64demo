; =============================================================================
; A16_logo_themes.asm - A16 Logo colour themes
; What you see: the "opencode" block logo with a diagonal colour gradient
; sweeping through it. Every 4 seconds the palette changes: rainbow,
; opencode grey/white, Rouen red & gold, ice, fire, Seine blue.
; Technique:
; - the logo is drawn once with reverse spaces ($a0); only colour RAM moves
; - colour of cell (x,row) = theme[(x + row*2 + phase) & 31] (as logo_colors
;   in src/main.asm). A theme is just a 32-byte gradient table
; - switching theme = pointing zp_theme at another table; its name is shown
; Docs: docs/08-effects-library.md (A16)
; =============================================================================
!source "c64.asm"

LOGO_ROW   = 8
LOGO_COL   = 4
NAME_ROW   = 16
THEME_TIME = 200                ; frames per theme
THEMES     = 6

zp_theme   = $20                ; 2 bytes: current gradient (32 bytes)
zp_name    = $22                ; 2 bytes
phase      = $24
tmp        = $25
theme      = $26
timer      = $27
frame_flag = $28

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$17
        sta VIC_MEMPTR
        lda #$20
        +fill_1000 SCREEN
        lda #BLACK
        +fill_1000 COLOR_RAM
        jsr draw_logo
        lda #0
        sta theme
        jsr set_theme

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
        jsr logo_colors
        dec timer
        bne main
        ldx theme               ; next theme
        inx
        cpx #THEMES
        bne +
        ldx #0
+       stx theme
        jsr set_theme
        jmp main

irq_frame:
        +irq_enter
        inc frame_flag
        +irq_exit

; theme X: gradient pointer, name on screen, restart the timer
set_theme:
        ldx theme
        lda theme_lo,x
        sta zp_theme
        lda theme_hi,x
        sta zp_theme+1
        lda name_lo,x
        sta zp_name
        lda name_hi,x
        sta zp_name+1
        ldy #19                 ; names are 20 chars, padded with spaces
-       lda (zp_name),y
        sta SCREEN+NAME_ROW*40+10,y
        lda #LIGHT_GREY
        sta COLOR_RAM+NAME_ROW*40+10,y
        dey
        bpl -
        lda #THEME_TIME
        sta timer
        rts

; diagonal gradient sweep through the 5 logo rows
logo_colors:
        inc phase
        ldx #30
-       txa
        clc
        adc phase
        sta tmp
        !for r, 0, 4 {
        lda tmp
        clc
        adc #r*2
        and #31
        tay
        lda (zp_theme),y
        sta COLOR_RAM+(LOGO_ROW+r)*40+LOGO_COL,x
        }
        dex
        bpl -
        rts

; '#' -> reverse space, anything else -> space
draw_logo:
        !for r, 0, 4 {
        ldx #30
-       lda logo_text+r*31,x
        ldy #$20
        cmp #'#'
        bne +
        ldy #$a0
+       tya
        sta SCREEN+(LOGO_ROW+r)*40+LOGO_COL,x
        dex
        bpl -
        }
        rts

nmi:    rti

logo_text: ; 5 rows x 31 columns, '#' = filled block
        !text "### ### ### ##  ### ### ##  ###"
        !text "# # # # #   # # #   # # # # #  "
        !text "# # ### ##  # # #   # # # # ## "
        !text "# # #   #   # # #   # # # # #  "
        !text "### #   ### # # ### ### ##  ###"

; ---- themes: 32-entry gradients (edit these!) ------------------------------
t_rainbow:  ; the one in src/main.asm (logo_gradient)
        !byte $06,$06,$04,$04,$0e,$0e,$03,$03,$0d,$0d,$01,$01,$0d,$0d,$03,$03
        !byte $0e,$0e,$04,$04,$06,$06,$0b,$0b,$0c,$0c,$0f,$0f,$0c,$0c,$0b,$0b
t_opencode: ; brand: greys with a white glint
        !fill 20, GREY
        !byte LIGHT_GREY, LIGHT_GREY, WHITE, WHITE, WHITE, LIGHT_GREY, LIGHT_GREY
        !fill 5, GREY
t_rouen:    ; red & gold
        !byte RED,RED,RED,RED,ORANGE,ORANGE,YELLOW,YELLOW,WHITE,YELLOW,YELLOW,ORANGE
        !byte ORANGE,RED,RED,RED,RED,RED,BROWN,BROWN,RED,RED,ORANGE,ORANGE
        !byte YELLOW,YELLOW,ORANGE,ORANGE,RED,RED,BROWN,BROWN
t_ice:
        !byte BLUE,BLUE,LIGHT_BLUE,LIGHT_BLUE,CYAN,CYAN,WHITE,WHITE
        !byte CYAN,CYAN,LIGHT_BLUE,LIGHT_BLUE,BLUE,BLUE,BLUE,BLUE
        !byte LIGHT_BLUE,LIGHT_BLUE,CYAN,CYAN,WHITE,WHITE,WHITE,WHITE
        !byte CYAN,CYAN,LIGHT_BLUE,LIGHT_BLUE,BLUE,BLUE,BLUE,BLUE
t_fire:
        !byte BROWN,BROWN,RED,RED,ORANGE,ORANGE,LIGHT_RED,LIGHT_RED
        !byte YELLOW,YELLOW,WHITE,WHITE,YELLOW,YELLOW,LIGHT_RED,LIGHT_RED
        !byte ORANGE,ORANGE,RED,RED,BROWN,BROWN,BROWN,BROWN
        !byte RED,RED,ORANGE,ORANGE,RED,RED,BROWN,BROWN
t_seine:    ; mostly blue with light ripples
        !for i, 0, 3 {
        !byte BLUE,BLUE,BLUE,BLUE,BLUE,LIGHT_BLUE,CYAN,LIGHT_BLUE
        }

theme_lo: !byte <t_rainbow, <t_opencode, <t_rouen, <t_ice, <t_fire, <t_seine
theme_hi: !byte >t_rainbow, >t_opencode, >t_rouen, >t_ice, >t_fire, >t_seine

n_rainbow:  !scr "  theme: rainbow    "
n_opencode: !scr "  theme: opencode   "
n_rouen:    !scr " theme: rouen gold  "
n_ice:      !scr "    theme: ice      "
n_fire:     !scr "    theme: fire     "
n_seine:    !scr "   theme: seine     "
name_lo: !byte <n_rainbow, <n_opencode, <n_rouen, <n_ice, <n_fire, <n_seine
name_hi: !byte >n_rainbow, >n_opencode, >n_rouen, >n_ice, >n_fire, >n_seine
