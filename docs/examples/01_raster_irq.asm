; =============================================================================
; 01_raster_irq.asm - chained raster interrupts (screen split)
; Two IRQ handlers that re-program each other: colour split at lines $80/$c0.
; This is the backbone of every demo: one handler per "zone" of the screen.
; Docs: docs/03-executable-basics.md, docs/04-demo-effects.md (#raster-irq)
; =============================================================================
!source "c64.asm"

        +basic_upstart

start:
        +demo_init nmi
        lda #$20                ; clear screen (leftover BASIC text otherwise)
        +fill_1000 SCREEN

        lda #$1b                ; DEN on, 25 rows, yscroll 3, raster bit 8 = 0
        sta VIC_CTRL1
        +set_irq irq_top, $80
        lda #$01
        sta VIC_IRQ_ENABLE      ; enable raster IRQ only
        sta VIC_IRQ_STATUS      ; ack any pending
        cli

        jmp *                   ; main program does nothing: all work in IRQs

; ---- zone 1: line $80 ---------------------------------------------------
irq_top:
        +irq_enter
        lda #BLUE
        sta BORDER
        sta BACKGROUND
        +set_irq irq_bottom, $c0 ; chain to next zone
        +irq_exit

; ---- zone 2: line $c0 ---------------------------------------------------
irq_bottom:
        +irq_enter
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        +set_irq irq_top, $80   ; back to first zone
        +irq_exit

nmi:    rti
