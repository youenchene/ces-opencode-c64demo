; =============================================================================
; A11_typewriter.asm - A11 Typewriter tweaks
; What you see: a terminal-style typer with a blinking cursor. The text
; changes colour, typing speed, pauses, clears the screen, then loops.
; Technique:
; - one byte stream, read by a per-frame routine; printable screen codes
;   go to (zp_cursor), the matching colour RAM cell gets the current colour
; - control bytes: $80-$8f colour, $f1-$f9 speed (frames per char),
;   $fc clear screen, $fd pause, $fe newline, $ff end (wait, then restart)
; - same byte set as typer_text in src/main.asm, plus speed and clear
; Docs: docs/08-effects-library.md (A11)
; =============================================================================
!source "c64.asm"

TYPE_SPEED   = 3                ; default frames per character
PAUSE_FRAMES = 40
END_FRAMES   = 150
TYPER_ROW    = 3
TYPER_COL    = 1
TYPER_START  = SCREEN + TYPER_ROW*40 + TYPER_COL

T_COLOR   = $80                 ; + colour 0-15
T_SPEED   = $f0                 ; + 1..9 frames per character
T_CLEAR   = $fc
T_PAUSE   = $fd
T_NEWLINE = $fe
T_END     = $ff

zp_text    = $20                ; 2 bytes: next byte of the text
zp_cursor  = $22                ; 2 bytes: screen address of the cursor
zp_line    = $24                ; 2 bytes: start of the current line
zp_color   = $26                ; 2 bytes: colour RAM address of the cursor
delay      = $28
speed      = $29
color      = $2a
frame      = $2b
frame_flag = $2c
ended      = $2d

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        lda #BLACK
        sta BACKGROUND
        lda #$17                ; lower/upper case ROM font
        sta VIC_MEMPTR
        jsr typer_reset

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
        jsr typer_update
        jmp main

irq_frame:
        +irq_enter
        inc frame_flag
        +irq_exit

; ---- clear screen, title, restart the text ---------------------------------
typer_reset:
        lda #<text
        sta zp_text
        lda #>text
        sta zp_text+1
        lda #TYPE_SPEED
        sta speed
        sta delay
        lda #WHITE
        sta color
        lda #0
        sta ended
clear_home:
        lda #$20
        +fill_1000 SCREEN
        lda #GREY
        +fill_1000 COLOR_RAM
        ldx #title_end-title-1
-       lda title,x
        sta SCREEN+40+1,x
        lda #DARK_GREY
        sta COLOR_RAM+40+1,x
        dex
        bpl -
        lda #<TYPER_START
        sta zp_line
        sta zp_cursor
        lda #>TYPER_START
        sta zp_line+1
        sta zp_cursor+1
        rts

; ---- one frame of typing ---------------------------------------------------
typer_update:
        dec delay
        bne .cursor
        lda speed
        sta delay
.next:  ldy #0
        lda (zp_text),y
        cmp #T_END
        bne +
        lda ended               ; first time: wait END_FRAMES, then restart
        bne typer_reset
        inc ended
        lda #END_FRAMES
        sta delay
        bne .cursor
+       inc zp_text             ; consume the byte (A preserved)
        bne +
        inc zp_text+1
+       cmp #T_NEWLINE
        bne +
        lda #$20                ; erase the cursor, go to next line
        sta (zp_cursor),y
        lda zp_line
        clc
        adc #40
        sta zp_line
        sta zp_cursor
        lda zp_line+1
        adc #0
        sta zp_line+1
        sta zp_cursor+1
        jmp .cursor
+       cmp #T_PAUSE
        bne +
        lda #PAUSE_FRAMES
        sta delay
        bne .cursor
+       cmp #T_CLEAR
        bne +
        jsr clear_home
        jmp .next
+       cmp #T_SPEED            ; $f0-$fb: new speed, then next byte now
        bcc +
        and #$0f
        sta speed
        jmp .next
+       cmp #T_COLOR+16         ; $80-$8f: colour change
        bcs .print
        cmp #T_COLOR
        bcc .print
        and #$0f
        sta color
        jmp .next
.print: sta (zp_cursor),y
        jsr .set_color
        inc zp_cursor
        bne .cursor
        inc zp_cursor+1
.cursor:                        ; blinking block cursor
        ldy #0
        lda frame
        and #$10
        beq +
        lda #$a0
        !byte $2c               ; BIT abs: skip the next 2-byte instruction
+       lda #$20
        sta (zp_cursor),y
.set_color:
        lda zp_cursor
        sta zp_color
        lda zp_cursor+1
        clc
        adc #>(COLOR_RAM-SCREEN)
        sta zp_color+1
        lda color
        sta (zp_color),y
        rts

nmi:    rti

title:  !scr "A11 typewriter tweaks"
title_end:

; Texts: avoid '@' (screen code 0) and "{|}~" (codes $5b-$5e)
text:
        !byte T_COLOR+LIGHT_GREEN
        !scr "$ ", T_COLOR+WHITE
        !scr "opencode", T_PAUSE, T_NEWLINE, T_NEWLINE
        !byte T_COLOR+LIGHT_BLUE
        !scr "> type slower please", T_PAUSE, T_NEWLINE
        !byte T_SPEED+8, T_COLOR+GREY
        !scr "  ok... like... this...", T_PAUSE, T_NEWLINE, T_NEWLINE
        !byte T_SPEED+3, T_COLOR+LIGHT_BLUE
        !scr "> now really fast!", T_PAUSE, T_NEWLINE
        !byte T_SPEED+1, T_COLOR+YELLOW
        !scr "  one char per frame: 50 chars/second,", T_NEWLINE
        !scr "  the whole line in under a second.", T_PAUSE, T_NEWLINE, T_NEWLINE
        !byte T_SPEED+2, T_COLOR+LIGHT_BLUE
        !scr "> colours?", T_PAUSE, T_NEWLINE
        !scr "  "
        !byte T_COLOR+RED, $a0, T_COLOR+ORANGE, $a0, T_COLOR+YELLOW, $a0
        !byte T_COLOR+GREEN, $a0, T_COLOR+CYAN, $a0, T_COLOR+BLUE, $a0
        !byte T_COLOR+PURPLE, $a0, T_COLOR+WHITE
        !scr " one control byte each", T_PAUSE, T_PAUSE, T_NEWLINE, T_NEWLINE
        !byte T_SPEED+3, T_COLOR+LIGHT_BLUE
        !scr "> clear the screen", T_PAUSE, T_PAUSE, T_CLEAR
        !byte T_COLOR+LIGHT_GREEN
        !scr "$ ", T_COLOR+WHITE
        !scr "make run", T_PAUSE, T_NEWLINE
        !byte T_SPEED+1, T_COLOR+GREY
        !scr "  building demo...", T_NEWLINE
        !scr "  ok, 4096 bytes", T_PAUSE, T_NEWLINE, T_NEWLINE
        !byte T_SPEED+3, T_COLOR+YELLOW
        !scr "  hello codeurs en seine!", T_END
