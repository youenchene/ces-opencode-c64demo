; =============================================================================
; 00_hello.asm - minimal runnable PRG skeleton
; - BASIC upstart (LOAD"*",8 / RUN works on a real C64)
; - takes over the machine (no KERNAL, no CIA IRQs)
; - clears screen, prints text, syncs main loop to the frame by polling $d012
; Build: make examples   (or: acme -I include -f cbm -o build/00_hello.prg docs/examples/00_hello.asm)
; Docs:  docs/03-executable-basics.md
; =============================================================================
!source "c64.asm"

        +basic_upstart          ; code starts at $080d

start:
        +demo_init nmi          ; sei, CIA off, $01=$35, NMI -> rti

        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$17                ; screen $0400, charset ROM lower/upper case
        sta VIC_MEMPTR

        lda #$20                ; space
        +fill_1000 SCREEN
        lda #LIGHT_GREEN
        +fill_1000 COLOR_RAM

        ldx #0                  ; print message on row 12
-       lda message,x
        beq +
        sta SCREEN+12*40+11,x
        inx
        bne -
+

main_loop:
-       lda VIC_RASTER          ; wait for raster line $ff (bottom border)
        cmp #$ff
        bne -
        inc frame
        lda frame
        lsr
        lsr
        lsr
        and #$0f
        sta BORDER              ; slow border colour cycle
-       lda VIC_RASTER          ; wait until we left line $ff
        cmp #$ff
        beq -
        jmp main_loop

nmi:    rti

frame:  !byte 0
message:
        !scr "hello from opencode"
        !byte 0
