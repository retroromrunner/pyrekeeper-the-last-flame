; PYREKEEPER NES - simplified assembler format
; iNES header (16 bytes)
    .org $0000
    .byte $4E, $45, $53, $1A  ; "NES" + $1A
    .byte $02                ; 2x16KB PRG
    .byte $01                ; 1x8KB CHR
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

; PRG ROM starts at $8000, but in file it's at offset $10
; We'll assemble with PC starting at $C000 (last 16KB) for vectors
; Actually for simplicity, assemble whole 32KB at $8000

    .org $8000

; ===== Constants =====
; (using direct addresses)

; ===== Reset =====
Reset:
    sei
    cld
    ldx #$40
    stx $4017
    ldx #$FF
    txs
    inx
    stx $2000
    stx $2001
    stx $4010

    bit $2002
VWait1:
    bit $2002
    bpl VWait1

    ; clear RAM
    txa
ClearRAM:
    sta $0000,x
    sta $0100,x
    sta $0200,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne ClearRAM

VWait2:
    bit $2002
    bpl VWait2

    ; init state
    lda #$00
    sta $00    ; state (0=title)
    sta $01    ; frame_cnt
    sta $10    ; score
    sta $11
    sta $12

    jsr InitPPU

    ; enable NMI
    lda #%10010000
    sta $2000
    lda #%00011110
    sta $2001

MainLoop:
    lda $02    ; nmi_ready
    beq MainLoop
    lda #$00
    sta $02

    jsr ReadJoy

    lda $00    ; state
    cmp #$00
    beq DoTitle
    cmp #$01
    beq DoPlay
    ; state 2 = over
    lda $05    ; joy_pressed
    and #$10   ; START
    beq MainLoop
    jmp StartGame

DoTitle:
    lda $05
    and #$10
    beq MainLoop
    jmp StartGame

DoPlay:
    jsr UpdateGame
    jmp MainLoop

; ===== NMI =====
NMI:
    pha
    txa
    pha
    tya
    pha
    lda #$00
    sta $2003
    lda #$02
    sta $4014
    inc $01    ; frame_cnt
    lda #$01
    sta $02    ; nmi_ready
    pla
    tay
    pla
    tax
    pla
    rti

IRQ:
    rti

; ===== ReadJoy =====
ReadJoy:
    lda $03    ; joy
    sta $04    ; joy_prev
    lda #$01
    sta $4016
    lda #$00
    sta $4016
    ldx #$08
    lda #$00
    sta $03
JoyLoop:
    lda $4016
    lsr
    rol $03
    dex
    bne JoyLoop
    lda $04
    eor #$FF
    and $03
    sta $05    ; joy_pressed
    rts

; ===== InitPPU =====
InitPPU:
    bit $2002
    lda #$3F
    sta $2006
    lda #$00
    sta $2006
    ldx #$00
PalLoop:
    lda Palette,x
    sta $2007
    inx
    cpx #$20
    bne PalLoop
    rts

Palette:
    .byte $0F,$16,$27,$37, $0F,$1A,$2A,$3A, $0F,$06,$16,$26, $0F,$09,$19,$29
    .byte $0F,$16,$27,$37, $0F,$1A,$2A,$3A, $0F,$06,$16,$26, $0F,$09,$19,$29

; ===== StartGame =====
StartGame:
    lda #$01
    sta $00    ; state=play
    lda #128
    sta $20    ; keeper_x
    lda #200
    sta $21    ; keeper_y
    lda #$03
    sta $22    ; hearts
    lda #$00
    sta $23    ; invuln
    lda #100
    sta $30    ; flame
    lda #$00
    sta $10
    sta $11
    sta $12
    lda #$01
    sta $13    ; wave
    ldx #$00
    txa
ClrShade:
    sta $40,x  ; shade_active
    inx
    cpx #$03
    bne ClrShade
    sta $50    ; bolt_active
    rts

; ===== UpdateGame =====
UpdateGame:
    ; move keeper
    lda $03
    and #$02   ; LEFT
    beq NotLeft
    dec $20
NotLeft:
    lda $03
    and #$01   ; RIGHT
    beq NotRight
    inc $20
NotRight:
    lda $03
    and #$08   ; UP
    beq NotUp
    dec $21
NotUp:
    lda $03
    and #$04   ; DOWN
    beq NotDown
    inc $21
NotDown:

    ; fire
    lda $05
    and #$40   ; B
    beq NoFire
    lda $50
    bne NoFire
    lda #$01
    sta $50
    lda $20
    sta $51
    lda $21
    sta $52
    lda #$00
    sta $53
    lda #$FC   ; -4
    sta $54
NoFire:

    ; update bolt
    lda $50
    beq NoBoltUpd
    lda $51
    clc
    adc $53
    sta $51
    lda $52
    clc
    adc $54
    sta $52
    cmp #240
    bcc BoltOK
    lda #$00
    sta $50
    jmp NoBoltUpd
BoltOK:
    ; check hit vs shades
    ldx #$00
ChkLoop:
    lda $40,x
    beq NextChk
    lda $51
    sec
    sbc $41,x
    cmp #16
    bcs NextChk
    lda $52
    sec
    sbc $44,x
    cmp #16
    bcs NextChk
    ; hit
    lda #$00
    sta $40,x
    sta $50
    lda $10
    clc
    adc #10
    sta $10
NextChk:
    inx
    cpx #$03
    bne ChkLoop
NoBoltUpd:

    ; spawn shades
    lda $01
    and #$3F
    bne NoSpawn
    ldx #$00
FindSlot:
    lda $40,x
    beq DoSpawn
    inx
    cpx #$03
    bne FindSlot
    jmp NoSpawn
DoSpawn:
    lda #$01
    sta $40,x
    lda $01
    and #$01
    beq SpawnLeft
    lda #240
    sta $41,x
    jmp SpawnY
SpawnLeft:
    lda #$08
    sta $41,x
SpawnY:
    lda #40
    sta $44,x
NoSpawn:

    ; move shades toward (128,120)
    ldx #$00
MvLoop:
    lda $40,x
    beq NextMv
    lda $41,x
    cmp #128
    beq XDone
    bcs MvLeft
    inc $41,x
    jmp XDone
MvLeft:
    dec $41,x
XDone:
    lda $44,x
    cmp #120
    beq YDone
    bcs MvUp
    inc $44,x
    jmp YDone
MvUp:
    dec $44,x
YDone:
    ; hit hearth?
    lda $41,x
    sec
    sbc #128
    cmp #$08
    bcs NextMv
    lda $44,x
    sec
    sbc #120
    cmp #$08
    bcs NextMv
    lda #$00
    sta $40,x
    lda $30
    sec
    sbc #10
    bcs FlameOK
    lda #$00
FlameOK:
    sta $30
NextMv:
    inx
    cpx #$03
    bne MvLoop

    ; drain
    lda $01
    and #$7F
    bne NoDrain
    dec $30
NoDrain:

    ; game over?
    lda $30
    bne FlameNotDead
    jmp DoGameOver
FlameNotDead:
    lda $22
    bne HeartsOK
    jmp DoGameOver
HeartsOK:

    jsr DrawSprites
    rts

DoGameOver:
    lda #$02
    sta $00
    ldx #$00
    lda #$FF
ClrOAM:
    sta $0200,x
    inx
    bne ClrOAM
    rts

; ===== DrawSprites =====
DrawSprites:
    ; keeper
    lda $21
    sta $0200
    lda #$00
    sta $0201
    sta $0202
    lda $20
    sta $0203
    ; bolt
    lda $50
    beq BoltOff
    lda $52
    sta $0204
    lda #$01
    sta $0205
    lda #$01
    sta $0206
    lda $51
    sta $0207
    jmp DoShades
BoltOff:
    lda #$FF
    sta $0204
DoShades:
    ldx #$00
    ldy #$08
ShLoop:
    lda $40,x
    beq ShOff
    lda $44,x
    sta $0200,y
    iny
    lda #$02
    sta $0200,y
    iny
    sta $0200,y
    iny
    lda $41,x
    sta $0200,y
    iny
    jmp ShNext
ShOff:
    lda #$FF
    sta $0200,y
    iny
    iny
    iny
    iny
ShNext:
    inx
    cpx #$03
    bne ShLoop
    ; hearth
    lda #120
    sta $0214
    lda $01
    lsr
    lsr
    and #$03
    clc
    adc #$10
    sta $0215
    lda #$03
    sta $0216
    lda #128
    sta $0217
    rts

; ===== Vectors =====
    .org $FFFA
    .word NMI
    .word Reset
    .word IRQ

; ===== CHR (8KB, filled with simple pattern) =====
    .org $0000
    ; We'll fill this in the file generation, not here
