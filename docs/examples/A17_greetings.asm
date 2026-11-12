; =============================================================================
; A17_greetings.asm - A17 Greetings list
; What you see: "greetings to" at the top; below it, group/sponsor names
; appear one at a time with a left-to-right colour wipe, stay ~2 seconds,
; wipe away, and the next name comes in. The list loops.
; Technique:
; - names: a table of zero-terminated !scr strings, ended by an extra 0
; - a name is written centred into screen RAM with colour RAM still BLACK
;   (= background), then revealed one column per frame (A10 column wipe):
;   colour[x] = gradient[row], hidden again the same way with BLACK
; - a 4-state machine: wipe in -> hold -> wipe out -> next name
; Docs: docs/08-effects-library.md (A17, uses A10)
; =============================================================================
!source "c64.asm"

NAME_ROW  = 9                   ; name block: 3 rows (9-11), all in page $05
!if >(SCREEN+NAME_ROW*40) != >(SCREEN+NAME_ROW*40+119) { !error "name rows must stay in one page" }
HOLD      = 100                 ; frames a name stays visible
GAP       = 15                  ; frames of empty screen between names

zp_name    = $20                ; 2 bytes: current name
state      = $22                ; 0 wipe in, 1 hold, 2 wipe out, 3 gap
col        = $23
timer      = $24
frame_flag = $25
zp_up      = $26                ; 2 bytes each: rows of the name block
zp_mid     = $28
zp_down    = $2a

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
        ldx #title_len-1        ; static title
-       lda title,x
        sta SCREEN+4*40+(40-title_len)/2,x
        lda #GREY
        sta COLOR_RAM+4*40+(40-title_len)/2,x
        dex
        bpl -
        lda #<names
        sta zp_name
        lda #>names
        sta zp_name+1
        jsr show_name

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
        jsr update
        jmp main

irq_frame:
        +irq_enter
        inc frame_flag
        +irq_exit

; ---- per-frame state machine ----------------------------------------------
update:
        lda state
        beq .wipe               ; 0: wipe in
        cmp #2
        beq .wipe               ; 2: wipe out
        dec timer               ; 1 hold / 3 gap
        bne .r
        lda state
        cmp #3
        beq .next
        lda #2                  ; hold over -> wipe out
        sta state
        lda #0
        sta col
.r:     rts
.next:  jsr next_name
        jmp show_name

.wipe:  ldx col                 ; one column of the 3 name rows
        lda state
        beq +
        lda #BLACK              ; wipe out
        sta COLOR_RAM+NAME_ROW*40,x
        sta COLOR_RAM+(NAME_ROW+1)*40,x
        sta COLOR_RAM+(NAME_ROW+2)*40,x
        jmp ++
+       lda #LIGHT_BLUE         ; wipe in: a little vertical gradient
        sta COLOR_RAM+NAME_ROW*40,x
        lda #WHITE
        sta COLOR_RAM+(NAME_ROW+1)*40,x
        lda #LIGHT_BLUE
        sta COLOR_RAM+(NAME_ROW+2)*40,x
++      inx
        stx col
        cpx #40
        bne .r
        inc state               ; 0 -> 1 hold, 2 -> 3 gap
        lda state
        cmp #1
        beq +
        lda #GAP
        !byte $2c               ; BIT abs: skip the next 2-byte instruction
+       lda #HOLD
        sta timer
        rts

; skip to the byte after the current name's 0; wrap at the final 0
next_name:
        ldy #0
-       lda (zp_name),y
        iny
        tax                     ; (sets Z from A)
        bne -
        tya
        clc
        adc zp_name
        sta zp_name
        bcc +
        inc zp_name+1
+       ldy #0
        lda (zp_name),y
        bne +
        lda #<names             ; end of list: back to the first name
        sta zp_name
        lda #>names
        sta zp_name+1
+       rts

; write the name centred on the middle row, with a line above and below.
; The 3 rows share one page, so only the low byte of the pointers differs.
show_name:
        lda #$20                ; clear the 3 rows (colour RAM stays black)
        ldx #119
-       sta SCREEN+NAME_ROW*40,x
        dex
        bpl -
        ldy #0                  ; length -> Y
-       lda (zp_name),y
        beq +
        iny
        bne -
+       tya                     ; first column = (40 - len) / 2
        eor #$ff
        sec
        adc #40
        lsr
        clc
        adc #<(SCREEN+NAME_ROW*40)
        sta zp_up               ; line above
        adc #40
        sta zp_mid              ; the name
        adc #40
        sta zp_down             ; line below
        lda #>(SCREEN+NAME_ROW*40)
        sta zp_up+1
        sta zp_mid+1
        sta zp_down+1
        dey
-       lda (zp_name),y         ; copy, last char first
        sta (zp_mid),y
        lda #$40                ; horizontal line char
        sta (zp_up),y
        sta (zp_down),y
        dey
        bpl -
        lda #0
        sta state
        sta col
        rts

nmi:    rti

title:  !scr "*** greetings to ***"
title_len = * - title

names:  ; zero-terminated names, list ends with an extra 0. Avoid '@' {|}~
        !scr "codeurs en seine", 0
        !scr "the opencode team", 0
        !scr "normandie web xperts", 0
        !scr "rouen developers", 0
        !scr "codebase64 wiki", 0
        !scr "csdb and all sceners", 0
        !scr "the vice team", 0
        !scr "you, in the kindarena!", 0
        !byte 0
