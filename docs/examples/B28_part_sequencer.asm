; =============================================================================
; B28_part_sequencer.asm - B28 Part sequencer
; What you see: three small parts that follow each other in a loop (colour
; cycling text, border pulse, random reveal), each with its own title; a bar
; on the bottom row shows the time left in the current part.
; Technique:
; - a table of parts: (duration in frames, init routine, per-frame routine),
;   ended by a 0 duration that loops back to the first part;
; - the main loop syncs on the frame, calls the current part's frame routine
;   through an indirect JMP, counts down, and on 0 starts the next part.
; - adding a part = writing two routines and one table line.
; Docs: docs/08-effects-library.md (B28), docs/04-demo-effects.md ("Parts")
; Limitations: transitions are hard cuts (a fade would be one more part).
; =============================================================================
!source "c64.asm"

pidx    = $20                   ; zero page: offset of the part in the table
cnt     = $21                   ; frames left (16 bit)
frame_vec = $23                 ; per-frame routine of the current part
init_vec  = $25
t       = $27                   ; free counter for the parts
ptr     = $28
pos     = $2a
tmp     = $2b

        +basic_upstart

start:
        +demo_init nmi
        lda #$17                ; screen $0400, ROM lowercase charset
        sta VIC_MEMPTR
        lda #0
        sta pidx
        jsr start_part

main:
-       lda VIC_RASTER          ; one tick per frame, below the display
        cmp #$fb
        bne -
        inc t
        jsr call_frame
        jsr draw_bar
        lda cnt                 ; 16-bit countdown
        bne +
        dec cnt+1
+       dec cnt
        lda cnt
        ora cnt+1
        bne +
        lda pidx                ; next part
        clc
        adc #6
        sta pidx
        jsr start_part
+
-       lda VIC_RASTER
        cmp #$fb
        beq -
        jmp main

call_frame:
        jmp (frame_vec)

; ---- load part pidx (wraps on the 0 entry) and run its init ----------------
start_part:
        ldy pidx
        lda parts,y
        ora parts+1,y
        bne +
        ldy #0                  ; end of table: loop
        sty pidx
+       lda parts,y
        sta cnt
        lda parts+1,y
        sta cnt+1
        lda parts+2,y
        sta init_vec
        lda parts+3,y
        sta init_vec+1
        lda parts+4,y
        sta frame_vec
        lda parts+5,y
        sta frame_vec+1
        lda #0
        sta t
        jsr clear               ; common: black screen, empty
        jmp (init_vec)

; ---- bottom row: one block per 4 frames left (max 40) ----------------------
draw_bar:
        lda cnt+1
        bne +
        lda cnt
        lsr
        lsr
        cmp #40
        bcc ++
+       lda #40
++      sta tmp                 ; bar length 0..40
        ldy #0
-       lda #$a0                ; solid block (reversed space)
        cpy tmp
        bcc +
        lda #$20                ; past the bar: space
+       sta SCREEN+24*40,y
        iny
        cpy #40
        bne -
        rts

; ---- the parts table --------------------------------------------------------
parts:  !word 200, p1_init, p1_frame
        !word 150, p2_init, p2_frame
        !word 200, p3_init, p3_frame
        !word 0

; ---- part 1: colour cycling text --------------------------------------------
p1_init:
        ldx #(t1_end-t1)-1
-       lda t1,x
        sta SCREEN+12*40+(40-(t1_end-t1))/2,x
        dex
        bpl -
        ldy #<title1
        ldx #>title1
        jmp print_title
p1_frame:
        ldx #39
-       txa
        clc
        adc t
        lsr
        and #15
        tay
        lda gradient,y
        sta COLOR_RAM+12*40,x
        dex
        bpl -
        rts

; ---- part 2: border/background pulse every 25 frames ------------------------
p2_init:
        ldy #<title2
        ldx #>title2
        jmp print_title
p2_frame:
        lda t
-       cmp #25                 ; t mod 25
        bcc +
        sbc #25
        bcs -
+       cmp #8
        bcs +
        tax
        lda fade,x
        sta BORDER
        sta BACKGROUND
        rts
+       lda #BLACK
        sta BORDER
        sta BACKGROUND
        rts

; ---- part 3: random reveal of 256 cells (rows 8-14) via colour RAM ---------
p3_init:
        lda #<(SCREEN+8*40)     ; fill rows 8-14 with a text pattern
        sta ptr
        lda #>(SCREEN+8*40)
        sta ptr+1
        ldy #0
        ldx #0
-       lda t3,x
        sta (ptr),y
        inx
        cpx #t3_end-t3
        bne +
        ldx #0
+       iny
        bne -
        lda #0
        sta pos
        ldy #<title3
        ldx #>title3
        jmp print_title
p3_frame:
        ldx #4                  ; 4 cells per frame -> 64 frames
-       lda pos                 ; pos = pos*5+1 mod 256: visits all 256 cells
        asl
        asl
        sec
        adc pos
        sta pos
        and #7
        tay
        lda revealcol,y
        ldy pos
        sta COLOR_RAM+8*40,y
        dex
        bne -
        rts

; ---- helpers ------------------------------------------------------------------
clear:
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        +fill_1000 COLOR_RAM    ; black text: parts set their own colours
        lda #$20
        +fill_1000 SCREEN
        lda #DARK_GREY          ; bottom bar colour
        ldx #39
-       sta COLOR_RAM+24*40,x
        dex
        bpl -
        rts

; Y/X = title (0-terminated) -> row 2, white
print_title:
        sty ptr
        stx ptr+1
        ldy #0
-       lda (ptr),y
        beq +
        sta SCREEN+2*40+2,y
        lda #WHITE
        sta COLOR_RAM+2*40+2,y
        iny
        bne -
+       rts

nmi:    rti

gradient: !byte 6, 6, 4, 14, 3, 13, 1, 1, 7, 15, 10, 8, 2, 9, 11, 0
revealcol: !byte 14, 3, 1, 13, 15, 7, 3, 14
fade:   !byte 1, 1, 15, 12, 12, 11, 11, 0
title1: !scr "part 1/3: colour cycling text", 0
title2: !scr "part 2/3: border pulse", 0
title3: !scr "part 3/3: random reveal", 0
t1:     !scr "codeurs en seine 2026 - rouen"
t1_end:
t3:     !scr "opencode "
t3_end:
