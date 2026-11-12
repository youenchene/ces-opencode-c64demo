; =============================================================================
; B01_2x2_scroller.asm - B1 2x2 scroller
; What you see: a big scroller in the middle of the screen, every letter is
;   2 chars wide and 2 chars high (16x16 pixels), yellow over orange.
; How:
; - at start the ROM font (64 chars) is scaled 2x into a 2 KB charset:
;   letter L = 4 chars: top-left L, top-right L+64, bottom-left L+128,
;   bottom-right L+192 (each font pixel -> 2x2 pixels, nibble lookup table)
; - $d016 fine scroll on the two scroller rows only (raster split), 38 cols
; - every 8 pixels both rows shift one char left; a new half letter enters
;   on the right (left half, then right half + next letter = every 2 steps)
; Docs: docs/08-effects-library.md (B1)
; Based on: codebase64 base:2x2_sidescroll, rewritten
; =============================================================================
!source "c64.asm"

CHARSET = $2000                 ; 2x2 font: 4 x 64 chars = 2 KB ($2000-$27ff)
ROW     = 11                    ; scroller uses rows 11 and 12
ROW1    = SCREEN + ROW*40
ROW2    = ROW1 + 40
SPLIT   = $33 + ROW*8 - 4       ; $87: inside blank row 10
RESTORE = $33 + (ROW+2)*8 + 1   ; $9c: inside blank row 13
SPEED   = 2                     ; pixels per frame (1..7)

zp_src  = $20                   ; 2 bytes
zp_dst  = $22                   ; 2 bytes
zp_p    = $24                   ; 2 bytes
zp_y    = $26
zp_l    = $27
zp_r    = $28
zp_text = $29                   ; 2 bytes
zp_half = $2b                   ; 0 = next is a left half, 1 = right half
zp_x    = $2c                   ; fine scroll 0..7

        +basic_upstart

start:
        +demo_init nmi
        jsr build_font          ; reads the char ROM: IRQs must be off
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM
        ldx #39
-       lda #YELLOW             ; top halves yellow, bottom halves orange
        sta COLOR_RAM+ROW*40,x
        lda #ORANGE
        sta COLOR_RAM+ROW*40+40,x
        lda title,x
        sta SCREEN+3*40,x
        lda info,x
        sta SCREEN+20*40,x
        dex
        bpl -
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        lda #0
        sta zp_half
        lda #7
        sta zp_x
        lda #$14                ; screen $0400, ROM uppercase font ($1000)
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_split, SPLIT
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *

; ---- above the scroller: 2x2 charset + fine scroll, 38 columns -------------
irq_split:
        +irq_enter
        lda zp_x
        sta VIC_CTRL2           ; bit 3 = 0 -> 38 columns
        lda #$18                ; charset $2000
        sta VIC_MEMPTR
        +set_irq irq_restore, RESTORE
        +irq_exit

; ---- below the scroller: ROM font, 40 columns, move the text ---------------
irq_restore:
        +irq_enter
        lda #$c8
        sta VIC_CTRL2
        lda #$14
        sta VIC_MEMPTR
        jsr update
        +set_irq irq_split, SPLIT
        +irq_exit

update:
        lda zp_x
        sec
        sbc #SPEED
        and #7
        sta zp_x
        bcs .done               ; no borrow: still inside the current char
        ldx #0                  ; shift both rows one char left
-       lda ROW1+1,x
        sta ROW1,x
        lda ROW2+1,x
        sta ROW2,x
        inx
        cpx #39
        bne -
        ldy #0
        lda (zp_text),y
        bne +                   ; 0 = end of text -> wrap
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        lda (zp_text),y
+       ldx zp_half
        bne .right
        sta ROW1+39             ; left half: L (top) and L+128 (bottom)
        ora #$80
        sta ROW2+39
        inc zp_half
        rts
.right: clc                     ; right half: L+64 (top) and L+192 (bottom)
        adc #64
        sta ROW1+39
        adc #128                ; carry clear: L+64 < 128
        sta ROW2+39
        lda #0
        sta zp_half
        inc zp_text             ; letter done -> next one
        bne .done
        inc zp_text+1
.done:  rts

; ---- scale ROM chars 0..63 to 2x2 chars -------------------------------------
build_font:
        lda #$33                ; char ROM at $d000, I/O hidden
        sta CPU_PORT
        lda #<$d000
        sta zp_src
        lda #>$d000
        sta zp_src+1
        lda #<CHARSET
        sta zp_dst
        lda #>CHARSET
        sta zp_dst+1
.char:  lda #0
        sta zp_y                ; font row 0..7
.row:   ldy zp_y
        lda (zp_src),y
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda expand,x            ; left nibble -> 8 pixels (left char)
        sta zp_l
        pla
        and #$0f
        tax
        lda expand,x            ; right nibble -> right char
        sta zp_r
        lda zp_y                ; rows 0-3 -> top chars, 4-7 -> bottom (+$400)
        and #4
        clc
        adc zp_dst+1
        sta zp_p+1
        lda zp_dst
        sta zp_p
        lda zp_y
        and #3
        asl                     ; each font row -> 2 char rows
        tay
        lda zp_l
        sta (zp_p),y
        iny
        sta (zp_p),y
        dey
        inc zp_p+1              ; right half = +$200 (char + 64)
        inc zp_p+1
        lda zp_r
        sta (zp_p),y
        iny
        sta (zp_p),y
        inc zp_y
        lda zp_y
        cmp #8
        bne .row
        lda zp_src              ; next char: +8 in ROM and in the charset
        clc
        adc #8
        sta zp_src
        bcc +
        inc zp_src+1
+       lda zp_dst
        clc
        adc #8
        sta zp_dst
        bcc +
        inc zp_dst+1
+       lda zp_dst+1
        cmp #>(CHARSET+$200)    ; 64 chars done?
        bne .char
        lda #BANK_IO_ONLY
        sta CPU_PORT
        rts

nmi:    rti

; nibble -> byte with every bit doubled (%0101 -> %00110011)
expand: !for n, 0, 15 { !byte ((n>>3)&1)*$c0 + ((n>>2)&1)*$30 + ((n>>1)&1)*$0c + (n&1)*$03 }

title:  !scr "         b1: 2x2 char scroller          "
info:   !scr "   each letter = 4 chars of a 2x font   "
; lowercase only (screen codes < 64), 0 ends the text
scroll_text:
        !scr "hello codeurs en seine 2026! this 2x2 scroller uses a scaled "
        !scr "rom font, 4 chars per letter ... written by opencode ...      "
        !byte 0
