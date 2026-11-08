; =============================================================================
; c64.asm - shared hardware constants & macros (ACME syntax)
; Include with:  !source "c64.asm"   (build with: acme -I include ...)
; Reference: docs/02-c64-architecture.md
; =============================================================================

; ---- CPU port -------------------------------------------------------------
CPU_DDR         = $00
CPU_PORT        = $01           ; memory banking (see docs/02)
BANK_ALL_ROM    = $37           ; BASIC + KERNAL + I/O (power-on default)
BANK_IO_ONLY    = $35           ; RAM everywhere except I/O at $d000 (demo default)
BANK_ALL_RAM    = $34           ; 64K RAM (no I/O!) - only with IRQs off

; ---- Default memory locations ---------------------------------------------
SCREEN          = $0400         ; default screen RAM (VIC bank 0)
COLOR_RAM       = $d800         ; color RAM (nybbles, fixed address)

; ---- Vectors (hardware, used when KERNAL is banked out) -------------------
NMI_VECTOR      = $fffa
RESET_VECTOR    = $fffc
IRQ_VECTOR      = $fffe

; ---- VIC-II ($d000) --------------------------------------------------------
VIC             = $d000
SPR0_X          = $d000         ; $d000-$d00f: sprite X/Y pairs
SPR0_Y          = $d001
SPR_X_MSB       = $d010
VIC_CTRL1       = $d011         ; bit7 raster MSB, bit6 ECM, bit5 BMM, bit4 DEN, bit3 RSEL, bits0-2 YSCROLL
VIC_RASTER      = $d012
VIC_LPX         = $d013
VIC_LPY         = $d014
SPR_ENABLE      = $d015
VIC_CTRL2       = $d016         ; bit4 MCM, bit3 CSEL (40/38 col), bits0-2 XSCROLL
SPR_EXPAND_Y    = $d017
VIC_MEMPTR      = $d018         ; bits4-7 screen /$400, bits1-3 charset /$800
VIC_IRQ_STATUS  = $d019
VIC_IRQ_ENABLE  = $d01a
SPR_PRIORITY    = $d01b
SPR_MULTICOLOR  = $d01c
SPR_EXPAND_X    = $d01d
SPR_SPR_COLL    = $d01e
SPR_BG_COLL     = $d01f
BORDER          = $d020
BACKGROUND      = $d021
BGCOLOR1        = $d022
BGCOLOR2        = $d023
BGCOLOR3        = $d024
SPR_MC0         = $d025
SPR_MC1         = $d026
SPR0_COLOR      = $d027         ; $d027-$d02e

; ---- SID ($d400) -----------------------------------------------------------
SID             = $d400
SID_VOLUME      = $d418

; ---- CIA ($dc00 / $dd00) ---------------------------------------------------
CIA1_PRA        = $dc00         ; keyboard columns / joystick 2
CIA1_PRB        = $dc01         ; keyboard rows   / joystick 1
CIA1_ICR        = $dc0d
CIA2_PRA        = $dd00         ; bits0-1: VIC bank (inverted)
CIA2_ICR        = $dd0d

; ---- Colors ----------------------------------------------------------------
BLACK = 0 : WHITE = 1 : RED = 2 : CYAN = 3 : PURPLE = 4 : GREEN = 5
BLUE = 6 : YELLOW = 7 : ORANGE = 8 : BROWN = 9 : LIGHT_RED = 10
DARK_GREY = 11 : GREY = 12 : LIGHT_GREEN = 13 : LIGHT_BLUE = 14 : LIGHT_GREY = 15

; =============================================================================
; Macros
; =============================================================================

; BASIC line "2026 SYS2061" at $0801. Code must start right after (at $080d).
!macro basic_upstart {
        * = $0801
        !word .next             ; pointer to next BASIC line
        !word 2026              ; line number
        !byte $9e               ; SYS token
        !text "2061"            ; decimal address of code ($080d)
        !byte 0                 ; end of line
.next   !word 0                 ; end of program
        ; -> $080d
}

; Standard demo takeover: IRQs off, CIA interrupts off, KERNAL/BASIC banked
; out, NMI (RESTORE key) neutralised. Leaves interrupts DISABLED (sei).
!macro demo_init .nmi_rti {
        sei
        cld
        lda #$7f
        sta CIA1_ICR            ; disable all CIA1 interrupts (timer IRQ)
        sta CIA2_ICR            ; disable all CIA2 interrupts (NMI)
        lda CIA1_ICR            ; acknowledge any pending
        lda CIA2_ICR
        lda #BANK_IO_ONLY
        sta CPU_PORT            ; RAM at $a000/$e000, I/O visible
        lda #<.nmi_rti
        sta NMI_VECTOR
        lda #>.nmi_rti
        sta NMI_VECTOR+1
}

; Set raster IRQ handler (KERNAL banked out -> use $fffe) and line (0-255).
!macro set_irq .handler, .line {
        lda #<.handler
        sta IRQ_VECTOR
        lda #>.handler
        sta IRQ_VECTOR+1
        lda #.line
        sta VIC_RASTER
}

; Save / restore A,X,Y in an IRQ handler (KERNAL off: we must do it ourselves)
!macro irq_enter {
        pha
        txa
        pha
        tya
        pha
}
!macro irq_exit {
        lda #$01
        sta VIC_IRQ_STATUS      ; acknowledge raster IRQ
        pla
        tay
        pla
        tax
        pla
        rti
}

; Fill 1000 bytes (screen or color RAM) with A. Clobbers X.
!macro fill_1000 .addr {
        ldx #0
-       sta .addr,x
        sta .addr+$100,x
        sta .addr+$200,x
        sta .addr+$2e8,x        ; overlaps, ends exactly at +999
        inx
        bne -
}
