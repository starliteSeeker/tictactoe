;== Include memorymap, header info, and SNES initialization routines
.INCLUDE "header.inc"
.INCLUDE "InitSNES.asm"

.macro ConvertX
; Data in: our coord in A
; Data out: SNES scroll data in C (the 16 bit A)
.rept 5
asl a           ; multiply A by 32
.endr
rep #%00100000  ; 16 bit A
clc
adc #(16 * 5)
eor #$FFFF      ; this will do A=1-A
inc a           ; A=A+1
sep #%00100000  ; 8 bit A
.endm

.macro ConvertY
; Data in: our coord in A
; Data out: SNES scroll data in C (the 16 bit A)
.rept 5
asl a           ; multiply A by 32
.endr
rep #%00100000  ; 16 bit A
clc
adc #(16 * 4)
eor #$FFFF      ; this will do A=1-A
sep #%00100000  ; 8 bit A
.endm

.DEFINE CURSOR_X $0100
.DEFINE CURSOR_Y $0101
.DEFINE CURSOR_STATE $0102
.DEFINE CURSOR_STATE_EN %00000001 ; 0 = disable, 1 = enable
.DEFINE CURSOR_STATE_OX %00000010 ; 0 = O, 1 = X

.DEFINE MARKS $0210 ; how many mark has been put down

;========================
; Start
;========================

.BANK 0 SLOT 0
.ORG 0
.SECTION "MainCode"

Start:
    InitializeSNES            ; Init Snes :)

    rep #%00010000  ;16 bit xy
    sep #%00100000  ;8 bit ab

    ; load palette
    lda #$00 ; start from palette 0
    sta $2121
    ldx #palettes
    lda #:palettes
    ldy #(palettes@end - palettes)
    stx $4302
    sta $4304
    sty $4305
    lda #%00000010 ; 1 addr write once
    sta $4300
    lda #$22
    sta $4301
    lda #%00000001      ; start DMA, channel 0
    sta $420B

    ; load tiles
    ldx #tiles   ; Address
    lda #:tiles  ; of tiles
    ldy #(tiles@end - tiles)      ; length of data
    stx $4302           ; write
    sta $4304           ; address
    sty $4305           ; and length
    lda #%00000001      ; set this mode (transferring words)
    sta $4300
    lda #$18            ; $211[89]: VRAM data write
    sta $4301           ; set destination

    ldy #$0000          ; Write to VRAM from $0000
    sty $2116

    lda #%00000001      ; start DMA, channel 0
    sta $420B

    lda #%10000000	; VRAM writing mode
    sta $2115
    ldx #($4000 + 32 * 4 + 5)	    ; write to vram
    stx $2116       ; from $4000

    ;ugly code starts here - it writes the # shape I mentioned before.
    .rept 2
        ;X|X|X
        .rept 2
            ldx #$0000 ; tile 0 ( )
            stx $2118
            ldx #$0002 ; tile 2 (|)
            stx $2118
        .endr
        ldx #$0000
        stx $2118
        ;first line finished, add BG's
        .rept 27
            stx $2118  ; X=0
        .endr
        ;beginning of 2nd line
        ;-+-+-
        .rept 2
            ldx #$0004 ; tile 4 (-)
            stx $2118
            ldx #$0006 ; tile 6 (+)
            stx $2118
        .endr
        ldx #$0004   ; tile 4 (-)
        stx $2118
        ldx #$0000
        .rept 27
            stx $2118
        .endr
    .endr
    .rept 2
        ldx #$0000    ; tile 0 ( )
        stx $2118
        ldx #$0002    ; tile 2 (|)
        stx $2118
    .endr

    ldx #$6000  ; BG2 will start here
    stx $2116
    ldx #$000C  ; And will contain 1 tile
    stx $2118

    ;set up the screen
    lda #%00110000  ; 16x16 tiles, mode 0
    sta $2105       ; screen mode register
    lda #%01000000  ; data starts from $4000
    sta $2107       ; for BG1
    lda #%01100000  ; and $6000
    sta $2108       ; for BG2

    stz $210B	    ; BG1 and BG2 use the $0000 tiles

    lda #%00000011  ; enable bg1 and 2
    sta $212C

    ;The PPU doesn't process the top line, so we scroll down 1 line.
    rep #$20        ; 16bit a
    lda #$07FF      ; this is -1 for BG1
    sep #$20        ; 8bit a
    sta $210E       ; BG1 vert scroll
    xba
    sta $210E

    rep #$20        ; 16bit a
    lda #$07ff      ; this is -1 for BG2
    sep #$20        ; 8bit a
    sta $2110       ; BG2 vert scroll
    xba
    sta $2110

    lda #%00001111  ; enable screen, set brightness to 15
    sta $2100

    lda #$01
    sta CURSOR_STATE

    lda #%10000001  ; enable NMI and joypads
    sta $4200

forever:
    wai
    rep #%00100000  ; get 16 bit A
    lda #$0000      ; empty it
    sep #%00100000  ; 8 bit A
    lda CURSOR_X       ; get our X coord
    ConvertX       ; WLA needs a space before a macro name
    sta $210F       ; BG2 horz scroll
    xba
    sta $210F       ; write 16 bits

    ;now repeat it, but change $0100 to $0101, and $210F to $2110
    rep #%00100000  ; get 16 bit A
    lda #$0000      ; empty it
    sep #%00100000  ; 8 bit A
    lda CURSOR_Y       ; get our Y coord
    ConvertY       ; WLA needs a space before a macro name
    sta $2110       ; BG2 vert scroll
    xba
    sta $2110       ; write 16 bits

    ldx #$0000; reset our counter
    -
    lda VRAMtableH.l,x  ; this is a long indexed address, nice :)
    xba
    lda VRAMtableL.l,x  ; this is a long indexed address, nice :)
    rep #%00100000
    clc
    adc #$4000         ; add $4000 to the value
    sta $2116          ; write to VRAM from here
    lda #$0000         ; reset A while it's still 16 bit
    sep #%00100000     ; 8 bit A
    lda $0000,x        ; get the corresponding tile from RAM
    ; VRAM data write mode is still %10000000
    sta $2118          ; write
    stz $2119          ; this is the hi-byte
    inx
    cpx #9             ; finished?
    bne -              ; no, go back

    ; check game over condition
    ; lda CURSOR_STATE
    ; bit #CURSOR_STATE_EN
    ; beq forever
    jsr checkWin
    bne endGame
resetGame:
    jmp forever

endGame:
    cmp #$01
    bne +
    ; draw
    ldx #$4166
    stx $2116
    ldx #$0000
-   lda DrawMsg.l, x
    sta $2118
    stz $2119
    inx
    cpx #4
    bne -
    jmp endGameLoop

    ; win
+   ldx #$4165
    stx $2116
    sta $2118
    stz $2119
    ldx #$0000
-   lda WinMsg.l, x
    sta $2118
    stz $2119
    inx
    cpx #4
    bne -
endGameLoop:
    wai
    lda CURSOR_STATE
    bit #CURSOR_STATE_EN
    bne resetGame
    jmp endGameLoop


; Check if O or X has win the game
; Data out: A = 0 if nothing, = $08 if O win, = $0A if X win, = $01 if draw
checkWin:
    ; 3 checks from top left
    lda $0000
    beq ++ ; value is not 0 ...
    cmp $0001 ; ... and equal to 2 other spaces
    bne +
    cmp $0002
    bne +
    bra win
+   cmp $0003
    bne +
    cmp $0006
    bne +
    bra win
+   cmp $0004
    bne +
    cmp $0008
    bne +
    bra win
    ; 2 checks from bottom left
++
+   lda $0006
    beq ++
    cmp $0004
    bne +
    cmp $0002
    bne +
    bra win
+   cmp $0007
    bne +
    cmp $0008
    bne +
    bra win
    ; 2 check from center right
++
+   lda $0005
    beq ++
    cmp $0004
    bne +
    cmp $0003
    bne +
    bra win
+   cmp $0002
    bne +
    cmp $0008
    bne +
    bra win
    ; 1 check from top middle
++
+   lda $0001
    beq ++
    cmp $0004
    bne +
    cmp $0007
    bne +
    bra win

    ; if all space have been filled ...
++
+   lda MARKS
    cmp #9
    bne nothing
    ; ... game end, draw
    lda #CURSOR_STATE_EN
    trb CURSOR_STATE
    lda #$01
    rts
win:
    tax
    lda #CURSOR_STATE_EN
    trb CURSOR_STATE
    txa
    rts
nothing:
    lda #$00
    rts

VBlank:
    lda $4212       ; get joypad status
    and #%00000001  ; if joy is not ready
    bne VBlank      ; wait
    lda $4219       ; read joypad (BYSTudlr)
    sta $0201       ; store it
    cmp $0200       ; compare it with the previous
    bne +           ; if not equal, go
    rti	            ; if it's equal, then return

+   sta $0200     ; store
    and #%00010000  ; get the start button
                    ; this will be the delete key
    beq +           ; if it's 0, we don't have to delete
    ldx #$0000
    - stz $0000,x   ; delete addresses $0000 to $0008
    inx
    cpx #$09        ; this is 9. Guess why (homework :) )
    bne -
    stz $0100       ; delete the scroll
    stz $0101       ; data also
    lda #$01 ; reset cursor state
    sta CURSOR_STATE
    stz MARKS ; reset marks count to 0
    ; remove win/draw message
    ldx #$4165
    stx $2116
    ldy #5
    ldx #$0000
-   stx $2118
    dey
    bne -


    ; can't move cursor if game ended
+   lda CURSOR_STATE
    bit #CURSOR_STATE_EN
    bne +
    rti

    + lda $0201     ; get back the temp value
    and #%11000000  ; Care only about B and Y
    beq +           ; if empty, skip this
    ; B or Y is pressed
    ; calculate where to put OX, y * 3 + x
    lda #$00
    xba
    lda CURSOR_Y
    sta $0202
    clc
    adc $0202
    adc $0202
    adc CURSOR_X
    tax
    ; skip if the space is already occupied
    lda $0000, x
    bne +
    
    ; check whether to put O or X
    lda CURSOR_STATE
    eor #CURSOR_STATE_OX
    sta CURSOR_STATE
    bit #CURSOR_STATE_OX
    beq putX ; flipped because the value has been eor'ed
putO:
    lda #$0a
    jmp storeOX
putX:
    lda #$08
storeOX:
    sta $0000, x
    inc MARKS

+
    ; cursor moving comes now
    lda $0201       ; get control
    and #%00001111  ; care about directions
    sta $0201       ; store this

    cmp #%00001000  ; up?
    bne +           ; if not, skip
    lda $0101       ; get scroll Y
    cmp #$00        ; if on the top,
    beq +           ; don't do anything
    dec $0101       ; sub 1 from Y
    +

    lda $0201       ; get control
    cmp #%00000100  ; down?
    bne +           ; if not, skip
    lda $0101
    cmp #$02        ; if on the bottom,
    beq +           ; don't do anything
    inc $0101       ; add 1 to Y
    +

    lda $0201       ; get control
    cmp #%00000010  ; left?
    bne +           ; if not, skip
    lda $0100
    cmp #$00        ; if on the left,
    beq +           ; don't do anything
    dec $0100       ; sub 1 from X
    +

    lda $0201       ; get control
    cmp #%00000001  ; right?
    bne +           ; if not, skip
    lda $0100
    cmp #$02        ; if on the right,
    beq +           ; don't do anything
    inc $0100       ; add 1 to X
    +
    rti             ; F|NisH3D!
.ENDS

.bank 1 slot 0       ; We'll use bank 1
.org 0
.section "Tiledata"
.include "tiles.inc" ; If you are using your own tiles, replace this
.include "palettes.inc"
.ends

.bank 2 slot 0
.org 0
.section "Conversiontable"
VRAMtableL:
.db $85,$87,$89,$c5,$c7,$c9,$05,$07,$09
VRAMtableH:
.db $00,$00,$00,$00,$00,$00,$01,$01,$01

WinMsg:
.db $00, $0e, $20, $22
DrawMsg:
.db $24, $26, $28, $0e

.ends

;write this after the conversion routine, just before jmp forever
