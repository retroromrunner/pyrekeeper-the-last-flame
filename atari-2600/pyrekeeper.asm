    processor 6502

; ==================== TIA registers ====================
VSYNC   = $00
VBLANK  = $01
WSYNC   = $02
NUSIZ0  = $04
NUSIZ1  = $05
COLUP0  = $06
COLUP1  = $07
COLUPF  = $08
COLUBK  = $09
CTRLPF  = $0A
REFP0   = $0B
REFP1   = $0C
PF0     = $0D
PF1     = $0E
PF2     = $0F
RESP0   = $10
RESP1   = $11
RESM0   = $12
RESM1   = $13
RESBL   = $14
AUDC0   = $15
AUDC1   = $16
AUDF0   = $17
AUDF1   = $18
AUDV0   = $19
AUDV1   = $1A
GRP0    = $1B
GRP1    = $1C
ENAM0   = $1D
ENAM1   = $1E
ENABL   = $1F
HMP0    = $20
HMP1    = $21
HMM0    = $22
HMM1    = $23
HMBL    = $24
HMOVE   = $2A
HMCLR   = $2B
CXCLR   = $2C

CXM0P   = $30
CXPPMM  = $37
INPT4   = $3C

SWCHA   = $0280
INTIM   = $0284
TIM64T  = $0296

; ==================== RAM ($80-$C7) ====================
FrameCnt  = $80
GameState = $81  ; 0=title 1=play 2=gameover
Rand      = $82
Score     = $83  ; 2 BCD bytes, 4 digits
Flame     = $85  ; 0-100
Hearts    = $86
WaveNum   = $87
KeeperX   = $88
KeeperY   = $89
KeeperDir = $8A
Invuln    = $8B
FireCool  = $8C
InfernoT  = $8D
DrainT    = $8E
SpawnT    = $8F
ShadeSlot = $90
SpawnQueue= $91
WavePause = $92
BoltX     = $93
BoltY     = $94
BoltDX    = $95
BoltDY    = $96
BoltLife  = $97
SX0       = $98  ; shade structs: X,Y,HP,Flags (4 bytes each, 3 slots)
SY0       = $99
SHP0      = $9A
SFL0      = $9B
SX1       = $9C
SY1       = $9D
SHP1      = $9E
SFL1      = $9F
SX2       = $A0
SY2       = $A1
SHP2      = $A2
SFL2      = $A3
SfxT      = $A4  ; 2 bytes: ch0,ch1 timers
SfxC      = $A6
SfxF      = $A8
SfxV      = $AA
SfxS      = $AC
D1        = $AE  ; 6 digit pointers, 12 bytes $AE-$B9
D2        = $B0
D3        = $B2
D4        = $B4
D5        = $B6
D6        = $B8
Tmp0      = $BA
Tmp1      = $BB
Tmp2      = $BC
TP        = $BD  ; text pointer $BD-$BE
BarPF0    = $BF
BarPF1    = $C0
BarPF2    = $C1
P1Y       = $C2
ColM0P    = $C3
ColPP     = $C4
BossFlag  = $C5
FlameH    = $C6
FlameTop  = $C7

HearthX   = 80
HearthY   = 90
HearthBase= 96

    org $F000

; ==================== ENTRY ====================
Start:
    sei
    cld
    ldx #$FF
    txs
    ldx #0
    txa
ClearRam:
    sta $80,x
    inx
    cpx #$80
    bne ClearRam
    ; clear TIA ($00-$2C)
    ldx #$2C
    lda #0
ClearTia:
    sta $00,x
    dex
    bpl ClearTia

    lda #$01
    sta Rand
    lda #$00
    sta GameState
    sta REFP0
    sta REFP1

MainLoop:
    lda GameState
    cmp #1
    bne MainNotPlay
    jmp PlayFrame
MainNotPlay:
    cmp #2
    bne MainNotOver
    jmp OverFrame
MainNotOver:
    jmp TitleFrame

; ==================== VSYNC (3 lines) ====================
VSYNC3:
    lda #2
    sta VSYNC
    sta WSYNC
    sta WSYNC
    sta WSYNC
    lda #0
    sta VSYNC
    rts

; ==================== PosX ====================
; A = x (0-159), X = object (0=P0 1=P1 2=M0 3=M1 4=BL)
PosX:
    sta WSYNC
    sec
Div15:
    sbc #15
    bcs Div15
    eor #7
    asl
    asl
    asl
    asl
    sta HMP0,x
    sta RESP0,x
    rts

; ==================== BlankLines ====================
; X = line count
BlankLines:
    sta WSYNC
    dex
    bne BlankLines
    rts

; ==================== Text12 ====================
; Draw 12 scanlines of playfield text. TP -> 72 bytes (12 rows x 6).
; Cycle-timed: PF2 is written twice per line; the 2nd write must land
; after px12-19 (clocks 116-143) but before px20-27 (clock 148).
Text12:
    ldy #0
    ldx #12
Text12Loop:
    sta WSYNC
    lda (TP),y
    sta PF0          ; byte0 -> px 0-3
    iny
    lda (TP),y
    sta PF1          ; byte1 -> px 4-11
    iny
    lda (TP),y
    sta PF2          ; byte2 -> px 12-19
    iny
    lda (TP),y       ; preload byte3
    iny
    nop              ; wait for px12-19 to finish
    nop
    sta PF2          ; byte3 -> px 20-27
    lda (TP),y
    sta PF1          ; byte4 -> px 28-35
    iny
    lda (TP),y
    sta PF0          ; byte5 -> px 36-39
    iny
    dex
    bne Text12Loop
    rts

; ==================== ScoreKernel ====================
; 8 scanlines, 6 digits via mid-line RESP. D1-D6 -> digit glyphs.
; 74 cycles/line. NUSIZ0/1 must be single-copy.
ScoreKernel:
    ldy #7
ScoreLine:
    sta WSYNC
    lda (D1),y
    sta GRP0
    sta RESP0
    lda (D2),y
    sta GRP1
    sta RESP1
    lda (D3),y
    sta GRP0
    sta RESP0
    lda (D4),y
    sta GRP1
    sta RESP1
    lda (D5),y
    sta GRP0
    sta RESP0
    lda (D6),y
    sta GRP1
    sta RESP1
    dey
    bpl ScoreLine
    rts

; ==================== BarKernel ====================
; 4 scanlines: hearts (PF0) + flame bar (PF1/PF2). GRP off.
BarKernel:
    ldy #4
BarLine:
    sta WSYNC
    lda #0
    sta GRP0
    sta GRP1
    lda BarPF0
    sta PF0
    lda BarPF1
    sta PF1
    lda BarPF2
    sta PF2
    dey
    bne BarLine
    lda #0
    sta PF0
    sta PF1
    sta PF2
    rts

; ==================== TITLE FRAME ====================
TitleFrame:
    jsr VSYNC3
    ; ---- VBLANK (37) ----
    lda #44
    sta TIM64T
    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta ENAM0
    sta ENAM1
    sta ENABL
    sta NUSIZ0
    sta NUSIZ1
    sta CTRLPF
    lda #$86
    sta COLUBK       ; dark blue
    lda #$0E
    sta COLUPF       ; white text
    ; hearth ball for title flame
    lda #80
    ldx #4
    jsr PosX
    sta WSYNC
    sta HMOVE
TitleVbw:
    lda INTIM
    bne TitleVbw
    jsr TitleKernel
    ; ---- overscan (30) ----
    lda #36
    sta TIM64T
    jsr NextFrame       ; FrameCnt++, Rand
    jsr AudioFrame
    lda INPT4
    bpl TitleNoFire
    jsr InitPlay
    lda #1
    sta GameState
TitleNoFire:
TitleOsw:
    lda INTIM
    bne TitleOsw
    jmp MainLoop

; ==================== TITLE KERNEL (192) ====================
TitleKernel:
    ldx #40
    jsr BlankLines
    lda #<TextPyre
    sta TP
    lda #>TextPyre
    sta TP+1
    jsr Text12
    lda #0
    sta PF0
    sta PF1
    sta PF2
    ldx #16
    jsr BlankLines
    ; title flame: 44 lines of flickering ball
    lda #$30
    sta CTRLPF          ; 8px wide ball
    lda #$2C
    sta COLUPF          ; orange
    ldx #44
TitleFlame:
    sta WSYNC
    txa
    clc
    adc FrameCnt
    and #$07
    cmp #$03
    bcc TitleFlameOff
    lda #2
    sta ENABL
    jmp TitleFlameNext
TitleFlameOff:
    lda #0
    sta ENABL
TitleFlameNext:
    dex
    bne TitleFlame
    lda #0
    sta ENABL
    ; PRESS FIRE (blink)
    lda FrameCnt
    and #$20
    beq TitleNoPress
    lda #<TextPress
    sta TP
    lda #>TextPress
    sta TP+1
    lda #$0E
    sta COLUPF
    jsr Text12
    lda #0
    sta PF0
    sta PF1
    sta PF2
    jmp TitleKernelDone
TitleNoPress:
    ldx #12
    jsr BlankLines
TitleKernelDone:
    ldx #68
    jsr BlankLines
    rts

; ==================== PLAY FRAME ====================
PlayFrame:
    jsr VSYNC3
    ; ---- VBLANK (37) ----
    lda #44
    sta TIM64T
    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta ENAM0
    sta ENAM1
    sta ENABL
    sta NUSIZ1          ; single for score kernel
    lda #$20
    sta NUSIZ0          ; P0 single, M0 4px wide
    jsr SetupScore
    jsr SetupBar
    ; colors for HUD
    lda #$0E
    sta COLUP0
    sta COLUP1          ; white digits
    lda #$2E
    sta COLUPF          ; orange bar
    lda #$86
    sta COLUBK
    ; position bolt + hearth ball
    lda BoltX
    ldx #2
    jsr PosX
    lda #HearthX
    ldx #4
    jsr PosX
    sta WSYNC
    sta HMOVE
    ; flame geometry + ball width/color
    lda Flame
    lsr
    lsr
    clc
    adc #6
    sta FlameH          ; 6..31
    lda #HearthBase
    sec
    sbc FlameH
    sta FlameTop
    lda Flame
    cmp #75
    bcs FlameWide
    cmp #35
    bcs FlameMid
    lda #$10            ; 2px
    jmp FlameWSet
FlameMid:
    lda #$20            ; 4px
    jmp FlameWSet
FlameWide:
    lda #$30            ; 8px
FlameWSet:
    sta CTRLPF
    lda FrameCnt
    and #$08
    beq FlameColA
    lda #$1E
    jmp FlameColSet
FlameColA:
    lda #$2C
FlameColSet:
    sta COLUPF
    jsr NextFrame
    jsr GameLogic
PlayVbw:
    lda INTIM
    bne PlayVbw
    ; ---- HUD: score (8) + bar (4) ----
    jsr ScoreKernel
    jsr BarKernel
    sta CXCLR
    ; ---- gameplay colors ----
    lda #$86
    sta COLUBK
    lda Invuln
    and #$04
    beq KeeperColNorm
    lda #$0E            ; blink white while invulnerable
    jmp KeeperColSet
KeeperColNorm:
    lda #$3C            ; orange keeper
KeeperColSet:
    sta COLUP0
    ; shade color set per-frame below (boss?)
    ; ---- position keeper + current shade ----
    lda KeeperX
    ldx #0
    jsr PosX
    jsr SelectShade     ; sets P1Y, positions P1, sets COLUP1/NUSIZ1
    sta WSYNC
    sta HMOVE
    ; ---- gameplay kernel (177) ----
    jsr GameKernel
    ; ---- overscan (30) ----
    lda #36
    sta TIM64T
    lda CXM0P
    sta ColM0P
    lda CXPPMM
    sta ColPP
    sta CXCLR
    jsr AudioFrame
PlayOsw:
    lda INTIM
    bne PlayOsw
    jmp MainLoop

; ==================== GAME KERNEL (179 lines) - TEST: solid red ====================
GameKernel:
    ldx #178
GameLineTest:
    sta WSYNC
    dex
    bpl GameLineTest
    rts

; ==================== GAME OVER FRAME ====================
OverFrame:
    jsr VSYNC3
    lda #44
    sta TIM64T
    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta ENAM0
    sta ENAM1
    sta ENABL
    sta NUSIZ0
    sta NUSIZ1
    lda #$86
    sta COLUBK
    lda #$0E
    sta COLUPF
    sta COLUP0
    sta COLUP1
    jsr SetupScore
OverVbw:
    lda INTIM
    bne OverVbw
    jsr OverKernel
    lda #36
    sta TIM64T
    jsr NextFrame
    jsr AudioFrame
    lda INPT4
    bpl OverNoFire
    lda #0
    sta GameState
OverNoFire:
OverOsw:
    lda INTIM
    bne OverOsw
    jmp MainLoop

; ==================== GAME OVER KERNEL (192) ====================
OverKernel:
    ldx #52
    jsr BlankLines
    lda #<TextOver
    sta TP
    lda #>TextOver
    sta TP+1
    jsr Text12
    lda #0
    sta PF0
    sta PF1
    sta PF2
    ldx #16
    jsr BlankLines
    jsr ScoreKernel
    ldx #8
    jsr BlankLines
    lda FrameCnt
    and #$20
    beq OverNoPress
    lda #<TextPress
    sta TP
    lda #>TextPress
    sta TP+1
    jsr Text12
    lda #0
    sta PF0
    sta PF1
    sta PF2
    jmp OverKernelDone
OverNoPress:
    ldx #12
    jsr BlankLines
OverKernelDone:
    ldx #84
    jsr BlankLines
    rts

; ==================== NextFrame ====================
; FrameCnt++, advance LFSR random
NextFrame:
    inc FrameCnt
    lda Rand
    asl
    bcc RandDone
    eor #$1D
RandDone:
    sta Rand
    rts

; ==================== SelectShade ====================
; Pick shade[ShadeSlot] for P1 this frame. Sets P1Y, positions P1,
; sets COLUP1 + NUSIZ1 (boss = double wide).
SelectShade:
    lda ShadeSlot
    asl
    asl
    tax                 ; 0,4,8
    lda SFL0,x
    and #$01
    beq ShadeInactive
    lda SY0,x
    sta P1Y
    lda SX0,x
    ldx #1
    jsr PosX
    ; color / size
    ldx ShadeSlot
    ; reload slot index -> flags: use P1Y trick? simpler: recompute
    lda ShadeSlot
    asl
    asl
    tax
    lda SFL0,x
    and #$02
    beq ShadeNormal
    lda #$BE            ; revenant: icy cyan
    sta COLUP1
    lda #$05            ; double-wide player
    sta NUSIZ1
    rts
ShadeNormal:
    lda #$AE            ; pale frost
    sta COLUP1
    lda #$00
    sta NUSIZ1
    rts
ShadeInactive:
    lda #$FF
    sta P1Y
    lda #0
    ldx #1
    jsr PosX
    lda #$00
    sta NUSIZ1
    rts

; ==================== SetupScore ====================
; D1-D6 -> glyph pointers for 4 BCD digits + 2 blanks.
SetupScore:
    lda Score
    and #$F0
    lsr
    lsr
    lsr
    lsr
    jsr DigitPtr0
    lda Score
    and #$0F
    jsr DigitPtr1
    lda Score+1
    and #$F0
    lsr
    lsr
    lsr
    lsr
    jsr DigitPtr2
    lda Score+1
    and #$0F
    jsr DigitPtr3
    lda #10
    jsr DigitPtr4
    lda #10
    jsr DigitPtr5
    rts
; A = digit 0-10. X = which pointer (0,2,4,6,8,10)
DigitPtr0:
    ldx #0
    jmp DigitPtr
DigitPtr1:
    ldx #2
    jmp DigitPtr
DigitPtr2:
    ldx #4
    jmp DigitPtr
DigitPtr3:
    ldx #6
    jmp DigitPtr
DigitPtr4:
    ldx #8
    jmp DigitPtr
DigitPtr5:
    ldx #10
DigitPtr:
    asl
    asl
    asl                 ; *8
    clc
    adc #<DigitFont
    sta D1,x
    lda #>DigitFont
    adc #0
    sta D1+1,x
    rts

; ==================== SetupBar ====================
; BarPF0 = hearts bits, BarPF1/2 = flame bar (width = Flame/6)
SetupBar:
    lda Hearts
    and #$07
    asl
    asl
    asl
    asl
    sta BarPF0
    lda Flame
    ldx #0
BarDiv:
    cmp #6
    bcc BarGotW
    sbc #6
    inx
    jmp BarDiv
BarGotW:
    lda BarPF1Tab,x
    sta BarPF1
    lda BarPF2Tab,x
    sta BarPF2
    rts

; ==================== InitPlay ====================
InitPlay:
    lda #70
    sta Flame
    lda #3
    sta Hearts
    lda #0
    sta Score
    sta Score+1
    sta KeeperDir
    sta BoltLife
    sta InfernoT
    sta Invuln
    sta FireCool
    sta WavePause
    sta BossFlag
    sta SfxT
    sta SfxT+1
    lda #1
    sta WaveNum
    lda #3
    sta SpawnQueue
    lda #60
    sta SpawnT
    lda #80
    sta KeeperX
    lda #30
    sta KeeperY
    lda #$FF
    sta BoltY           ; offscreen when inactive
    ldx #11
InitShadeClear:
    lda #0
    sta SX0,x
    dex
    bpl InitShadeClear
    lda #0
    sta AUDV0
    sta AUDV1
    rts

; ==================== GAME LOGIC (overscan) ====================
GameLogic:
    ; ---- inferno? ----
    lda InfernoT
    beq NoInferno
    dec InfernoT
    bne InfernoKill
    lda #65
    sta Flame
    jmp NoInferno
InfernoKill:
    ; incinerate all shades
    ldx #8
InfKillLoop:
    lda SFL0,x
    and #$01
    beq InfNext
    lda SFL0,x
    and #$FE
    sta SFL0,x
    lda #$25
    sta Tmp0
    lda #$00
    sta Tmp1
    jsr AddScore16
InfNext:
    dex
    dex
    dex
    dex
    bpl InfKillLoop
    jmp LogicDoneWaves  ; skip spawn/drain during inferno
NoInferno:
    ; ---- flame dead? ----
    lda Flame
    bne FlameAlive
    jmp DoGameOver
FlameAlive:
    ; ---- flame drain ----
    inc DrainT
    lda DrainT
    cmp #75
    bcc NoDrain
    lda #0
    sta DrainT
    dec Flame
    bne NoDrain
    jmp DoGameOver      ; flame died
NoDrain:
    ; ---- spawning ----
    lda SpawnT
    beq TrySpawn
    dec SpawnT
    jmp CheckWave
TrySpawn:
    lda SpawnQueue
    beq CheckWave
    jsr CountActive
    cmp #3
    bcs CheckWave
    jsr SpawnShade
    lda #80
    sta SpawnT
CheckWave:
    ; ---- wave clear? ----
    lda SpawnQueue
    bne LogicWaves
    jsr CountActive
    bne LogicWaves
    lda WavePause
    bne WavePausing
    lda #110
    sta WavePause
    lda #$50            ; wave bonus $0150
    sta Tmp0
    lda #$01
    sta Tmp1
    jsr AddScore16
    ldx #3              ; horn
    ldy #0
    jsr PlaySfx
    jmp LogicWaves
WavePausing:
    dec WavePause
    bne LogicWaves
    inc WaveNum
    lda WaveNum
    cmp #6
    bcc WaveQSmall
    lda #6
WaveQSmall:
    clc
    adc #2
    sta SpawnQueue      ; 3..8
    lda WaveNum
    and #$04            ; every 4th? use %5 below
    ; boss every 5th wave
    lda WaveNum
WaveMod5:
    cmp #5
    bcc WaveModDone
    sbc #5
    jmp WaveMod5
WaveModDone:
    bne LogicWaves
    lda #1
    sta BossFlag
LogicWaves:
LogicDoneWaves:
    ; ---- keeper movement ----
    jsr MoveKeeper
    ; ---- fire button ----
    lda FireCool
    beq FireReady
    dec FireCool
FireReady:
    lda INPT4
    bpl NoFireBtn
    lda FireCool
    bne NoFireBtn
    lda BoltLife
    bne NoFireBtn
    jsr FireBolt
NoFireBtn:
    ; ---- bolt move ----
    jsr MoveBolt
    ; ---- shades move ----
    jsr MoveShades
    ; ---- collisions ----
    jsr DoCollisions
    ; ---- invuln tick ----
    lda Invuln
    beq NoInvTick
    dec Invuln
NoInvTick:
    ; ---- shade draw slot ----
    inc ShadeSlot
    lda ShadeSlot
    cmp #3
    bcc SlotOk
    lda #0
    sta ShadeSlot
SlotOk:
    ; ---- audio crackle ----
    jsr AudioFrame
    rts

; CountActive -> A = number of active shades
CountActive:
    lda #0
    sta Tmp2
    ldx #8
CountLoop:
    lda SFL0,x
    and #$01
    beq CountNext
    inc Tmp2
CountNext:
    dex
    dex
    dex
    dex
    bpl CountLoop
    lda Tmp2
    rts

; SpawnShade: activate a free slot at a random edge
SpawnShade:
    ldx #8
FindSlot:
    lda SFL0,x
    and #$01
    beq GotSlot
    dex
    dex
    dex
    dex
    bpl FindSlot
    rts                 ; none free (shouldn't happen)
GotSlot:
    dec SpawnQueue
    lda BossFlag
    beq NormalShade
    lda #0
    sta BossFlag
    lda #3
    sta SHP0,x
    lda #$07            ; active + boss, tick=1
    sta SFL0,x
    jmp ShadePos
NormalShade:
    lda #1
    sta SHP0,x
    lda #$05            ; active, tick=1
    sta SFL0,x
ShadePos:
    ; random edge: Rand bits
    lda Rand
    and #$03
    beq EdgeTop
    cmp #1
    beq EdgeBottom
    cmp #2
    beq EdgeLeft
    ; right
    lda #150
    sta SX0,x
    jmp EdgeY
EdgeTop:
    lda #164
    sta SY0,x
    jmp EdgeX
EdgeBottom:
    lda #12
    sta SY0,x
    jmp EdgeX
EdgeLeft:
    lda #10
    sta SX0,x
    jmp EdgeY
EdgeX:
    lda Rand
    and #$7F
    clc
    adc #16
    sta SX0,x
    rts
EdgeY:
    lda Rand
    and #$7F
    clc
    adc #16
    sta SY0,x
    rts

; MoveKeeper: joystick -> KeeperX/Y + KeeperDir
MoveKeeper:
    lda SWCHA
    eor #$FF
    and #$F0
    lsr
    lsr
    lsr
    lsr                 ; idx 0-15 (u,d,l,r bits)
    tax
    lda DirTab,x
    bmi KeepDir         ; $FF = keep last dir / no move
    sta KeeperDir
    tax
    lda DXTab,x
    beq DXZero
    bmi DXNeg
    ; +x
    lda KeeperX
    clc
    adc #2
    cmp #149
    bcs DXClipHi
    sta KeeperX
    jmp DYMove
DXClipHi:
    lda #148
    sta KeeperX
    jmp DYMove
DXNeg:
    lda KeeperX
    sec
    sbc #2
    cmp #12
    bcc DXClipLo
    sta KeeperX
    jmp DYMove
DXClipLo:
    lda #12
    sta KeeperX
    jmp DYMove
DXZero:
DYMove:
    lda DYTab,x
    beq KeepDir
    bmi DYNeg
    lda KeeperY
    clc
    adc #2
    cmp #165
    bcs DYClipHi
    sta KeeperY
    jmp KeepDir
DYClipHi:
    lda #164
    sta KeeperY
    jmp KeepDir
DYNeg:
    lda KeeperY
    sec
    sbc #2
    cmp #12
    bcc DYClipLo
    sta KeeperY
    jmp KeepDir
DYClipLo:
    lda #12
    sta KeeperY
KeepDir:
    rts

DirTab:
    .byte $FF,0,4,$FF,6,7,5,$FF,2,1,3,$FF,$FF,$FF,$FF,$FF
DXTab:
    .byte 0,1,1,1,0,-1,-1,-1
DYTab:
    .byte 1,1,0,-1,-1,-1,0,1

; FireBolt: spawn bolt from keeper in KeeperDir
FireBolt:
    lda KeeperX
    sta BoltX
    lda KeeperY
    sta BoltY
    ldx KeeperDir
    lda DXTab,x
    sta BoltDX
    lda DYTab,x
    sta BoltDY
    lda #28
    sta BoltLife
    lda #12
    sta FireCool
    ldx #0              ; shoot sfx, ch0
    ldy #0
    jsr PlaySfx
    rts

; MoveBolt
MoveBolt:
    lda BoltLife
    beq BoltDone2
    dec BoltLife
    beq BoltDone2
    lda BoltX
    clc
    adc BoltDX
    adc BoltDX
    adc BoltDX
    adc BoltDX
    adc BoltDX
    adc BoltDX          ; +6*DX
    sta BoltX
    lda BoltY
    clc
    adc BoltDY
    adc BoltDY
    adc BoltDY
    adc BoltDY
    adc BoltDY
    adc BoltDY
    sta BoltY
    ; bounds
    lda BoltX
    cmp #6
    bcc BoltKill
    cmp #154
    bcs BoltKill
    lda BoltY
    cmp #6
    bcc BoltKill
    cmp #170
    bcc BoltDone2
BoltKill:
    lda #0
    sta BoltLife
BoltDone2:
    rts

; MoveShades: chase hearth, check arrival
MoveShades:
    ldx #8
ShadeLoop:
    lda SFL0,x
    and #$01
    bne ShadeActive
    jmp ShadeNext
ShadeActive:
    ; tick
    lda SFL0,x
    sec
    sbc #$04            ; tick -= 1 (bits 2-7)
    and #$FC
    sta Tmp0
    lda SFL0,x
    and #$03
    ora Tmp0
    sta SFL0,x
    and #$FC
    beq ShadeDoMove
    jmp ShadeNext
ShadeDoMove:
    ; reset tick: speed
    lda SFL0,x
    and #$02
    beq ShadeSpdNorm
    lda #3              ; boss speed
    jmp ShadeSpdSet
ShadeSpdNorm:
    lda #8
    sec
    sbc WaveNum
    lsr                 ; (8-wave)/2
    cmp #2
    bcs ShadeSpdSet
    lda #2
ShadeSpdSet:
    asl
    asl                 ; -> bits 2-7
    ora SFL0,x
    sta SFL0,x
    and #$03
    sta Tmp0
    lda SFL0,x
    and #$FC
    ora Tmp0
    sta SFL0,x
    ; move toward hearth
    lda SX0,x
    cmp #HearthX-4
    bcc ShadeGoRight
    cmp #HearthX+4+1
    bcs ShadeGoLeft
    jmp ShadeYMove
ShadeGoRight:
    inc SX0,x
    jmp ShadeYMove
ShadeGoLeft:
    dec SX0,x
ShadeYMove:
    lda SY0,x
    cmp #HearthY-4
    bcc ShadeGoUp
    cmp #HearthY+4+1
    bcs ShadeGoDown
    jmp ShadeArrived
ShadeGoUp:
    inc SY0,x
    jmp ShadeNext
ShadeGoDown:
    dec SY0,x
    jmp ShadeNext
    ; arrived: inside deadband on both axes -> hits the hearth
ShadeArrived:
    stx Tmp2
    lda SFL0,x
    and #$FE
    sta SFL0,x          ; deactivate
    lda Flame
    sec
    sbc #12
    bcs FlameArrOk
    lda #0
FlameArrOk:
    sta Flame
    ldx #5
    ldy #1
    jsr PlaySfx         ; thud
    ldx Tmp2
ShadeNext:
    dex
    dex
    dex
    dex
    bmi ShadeLoopEnd
    jmp ShadeLoop
ShadeLoopEnd:
    rts

; ==================== DoCollisions ====================
DoCollisions:
    ; ---- bolt vs shade (M0 vs P1) ----
    lda ColM0P
    and #$80
    beq NoBoltHit
    lda BoltLife
    beq NoBoltHit
    lda ShadeSlot
    asl
    asl
    tax
    lda SFL0,x
    and #$01
    beq NoBoltHit
    dec SHP0,x
    bne ShadeWounded
    ; shade killed
    lda SFL0,x
    and #$FE
    sta SFL0,x
    lda SFL0,x
    and #$02
    beq KillNorm
    lda #$00            ; boss: $0100
    sta Tmp0
    lda #$01
    sta Tmp1
    jmp KillScore
KillNorm:
    lda #$25
    sta Tmp0
    lda #$00
    sta Tmp1
KillScore:
    jsr AddScore16
    lda Flame
    clc
    adc #6
    cmp #101
    bcc FlameSetKill
    lda #100
FlameSetKill:
    sta Flame
    cmp #100
    bne NoInfernoStart
    jsr StartInferno
NoInfernoStart:
    ldx #1
    ldy #1
    jsr PlaySfx         ; kill sfx
    jmp BoltGone
ShadeWounded:
    ldx #1
    ldy #1
    jsr PlaySfx
BoltGone:
    lda #0
    sta BoltLife
NoBoltHit:
    ; ---- keeper vs shade (P0 vs P1) ----
    lda ColPP
    and #$80
    beq NoKeeperHit
    lda Invuln
    bne NoKeeperHit
    dec Hearts
    beq KeeperDied
    lda #120
    sta Invuln
    lda ShadeSlot
    asl
    asl
    tax
    lda SFL0,x
    and #$FE
    sta SFL0,x          ; the shade dies striking you
    ldx #2
    ldy #0
    jsr PlaySfx         ; hurt
    jmp NoKeeperHit
KeeperDied:
    jmp DoGameOver
NoKeeperHit:
    rts

; ==================== StartInferno ====================
StartInferno:
    lda #150
    sta InfernoT
    ldx #4
    ldy #1
    jsr PlaySfx
    rts

; ==================== DoGameOver ====================
DoGameOver:
    lda #2
    sta GameState
    lda #0
    sta AUDV0
    sta AUDV1
    ldx #6
    ldy #0
    jsr PlaySfx
    rts

; ==================== AddScore16 ====================
; Tmp0 = low BCD byte, Tmp1 = high BCD byte
AddScore16:
    sed
    clc
    lda Score
    adc Tmp0
    sta Score
    lda Score+1
    adc Tmp1
    sta Score+1
    cld
    rts

; ==================== AudioFrame ====================
AudioFrame:
    ldx #0
    jsr ChUpdate
    ldx #1
    jsr ChUpdate
    ; fire crackle on ch1 when free
    lda SfxT+1
    bne CrackleDone
    lda Rand
    and #$1F
    cmp #$02
    bcs CrackleDone
    lda #2
    sta SfxT+1
    lda #$08
    sta SfxC+1
    lda Rand
    sta SfxF+1
    lda #3
    sta SfxV+1
    lda #0
    sta SfxS+1
CrackleDone:
    rts
ChUpdate:
    lda SfxT,x
    beq ChSilent
    dec SfxT,x
    beq ChStop
    lda SfxF,x
    clc
    adc SfxS,x
    sta SfxF,x
    sta AUDF0,x
    lda SfxC,x
    sta AUDC0,x
    lda SfxV,x
    sta AUDV0,x
    rts
ChStop:
ChSilent:
    lda #0
    sta AUDV0,x
    rts

; ==================== PlaySfx ====================
; X = sfx id (0=shoot 1=kill 2=hurt 3=horn 4=inferno 5=thud 6=gameover), Y = channel
PlaySfx:
    lda SfxCDTab,x
    sta SfxC,y
    lda SfxFDTab,x
    sta SfxF,y
    lda SfxVDTab,x
    sta SfxV,y
    lda SfxSDTab,x
    sta SfxS,y
    lda SfxDDTab,x
    sta SfxT,y
    rts

SfxCDTab:
    .byte $04,$08,$04,$0C,$08,$08,$04
SfxFDTab:
    .byte 20,15,8,10,31,8,24
SfxVDTab:
    .byte 8,10,12,10,12,10,10
SfxSDTab:
    .byte $FF,$FF,$00,$00,$FF,$00,$FF
SfxDDTab:
    .byte 8,12,20,40,60,10,50

; ==================== DATA ====================
KeeperSpr:
    .byte $18,$3C,$3C,$18,$3C,$7E,$FF,$7E,$3C,$24
ShadeSpr:
    .byte $24,$66,$7E,$FF,$DB,$FF,$7E,$3C,$66,$24

DigitFont:
    ; 0
    .byte $7E,$FF,$C3,$C3,$C3,$C3,$FF,$7E
    ; 1
    .byte $18,$38,$18,$18,$18,$18,$18,$7E
    ; 2
    .byte $7E,$FF,$03,$06,$18,$30,$FF,$FF
    ; 3
    .byte $7E,$FF,$03,$06,$1C,$03,$FF,$7E
    ; 4
    .byte $18,$38,$78,$CC,$FF,$0C,$0C,$0C
    ; 5
    .byte $FF,$FF,$C0,$FC,$03,$03,$FF,$7E
    ; 6
    .byte $7E,$FF,$C0,$FC,$C3,$C3,$FF,$7E
    ; 7
    .byte $FF,$FF,$06,$0C,$18,$18,$18,$18
    ; 8
    .byte $7E,$FF,$C3,$C3,$7E,$C3,$C3,$7E
    ; 9
    .byte $7E,$FF,$C3,$C3,$FE,$03,$FF,$7E
    ; blank
    .byte $00,$00,$00,$00,$00,$00,$00,$00

    include "textdata.asm"

; ==================== VECTORS ====================
    org $FFFA
    .word Start
    .word Start
    .word Start
