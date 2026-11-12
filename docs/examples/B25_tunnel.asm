; =============================================================================
; B25_tunnel.asm - B25 Chunky tunnel (40x25 colour RAM)
; What you see: flying into a twisting checkerboard tunnel, fading to black
; in the distance, full screen.
; Technique:
; - the screen is filled with the solid block char ($a0): each char cell is a
;   "chunky pixel" whose colour comes from colour RAM;
; - per cell, two tables made at assemble time: distance d = k/r and angle
;   a = atan2(dy,dx), plus a fog level from r;
; - per update: colour = pal[(((d+z) XOR (a+t)) AND $10) OR fog]. Moving z
;   flies forward, moving t twists. No maths at run time, only adds and lookups.
; Docs: docs/08-effects-library.md (B25)
; Limitations: tunnel only (a rotozoomer uses the same u/v table idea). About
; 40 cycles x 1000 cells = 2 frames per update (25 fps), no double buffer:
; colour RAM can tear a little.
; =============================================================================
!source "c64.asm"

TABLES  = $2000
CELLS   = 1000

tz      = $20                   ; zero page: depth offset
tr      = $21                   ; twist offset
tmp     = $22

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        +fill_1000 COLOR_RAM
        lda #$a0                ; solid block (ROM charset, reversed space)
        +fill_1000 SCREEN
        lda #$15                ; screen $0400, ROM uppercase charset
        sta VIC_MEMPTR

main:
        ; one pass over the 1000 cells: X = 250..1, 4 chunks of 250 cells
        ldx #250
-       !for k, 0, 3 {
        lda dist + k*250 - 1,x  ; 4-5
        clc                     ; 2
        adc tz                  ; 3
        sta tmp                 ; 3
        lda ang + k*250 - 1,x   ; 4-5
        clc                     ; 2
        adc tr                  ; 3
        eor tmp                 ; 3
        and #$10                ; 2  checker bit
        ora fog + k*250 - 1,x   ; 4-5
        tay                     ; 2
        lda pal,y               ; 4
        sta COLOR_RAM + k*250 - 1,x ; 5  = ~41 cycles
        }
        dex
        beq +
        jmp -                   ; loop body is too long for a branch
+       lda tz                  ; fly forward
        sec
        sbc #3
        sta tz
        inc tr                  ; twist
        jmp main

nmi:    rti

; fog 0 (far, centre) .. 7 (near, edges); two checker colours
pal:    !byte 0, 6, 11, 4, 14, 14, 3, 1         ; fog 0-7, checker 0
        !fill 8, 0
        !byte 0, 0, 9, 2, 8, 8, 10, 7           ; fog 0-7, checker 1

        * = TABLES
PI = 3.14159265
; cell (cx, cy): dx = cx-19.5, dy = cy-12, r = (dx*dx+dy*dy)^0.5
!macro tunnel_table .what {
        !for i, 0, CELLS-1 {
        !set dx = (i MOD 40) - 19.5
        !set dy = float(i DIV 40) - 12
        !set r  = (dx * dx + dy * dy) ^ 0.5
        !if .what = 0 { !byte int(320 / r) & 255 }
        !if .what = 1 {
                !if dx > 0 { !set an = arctan(dy / dx) } else { !set an = arctan(dy / dx) + PI }
                !byte int(an * 128 / PI + 256) & 255
        }
        !if .what = 2 {
                !set f = int(r / 3)
                !byte (f > 7) * 7 + (f <= 7) * f
        }
        }
}
dist:   +tunnel_table 0
ang:    +tunnel_table 1
fog:    +tunnel_table 2
