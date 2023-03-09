.setting "HandleLongBranch", true

;assuming 10 MHz CLK for 65816
;assuming 2 MHz CLK for PSGs

PlaySongFromSDCard:
    ;TO DO: Add supporting to start at different addresses on SD Card. For now, starting to read music at 0x0.
    
    lda #<SND_RESET
    sta TUNE_PTR_LO
    lda #>SND_RESET
    sta TUNE_PTR_HI

    jsr AY1_PlayTune
    jsr AY2_PlayTune
    jsr AY3_PlayTune
    jsr AY4_PlayTune
    jsr AY5_PlayTune
    jsr AY6_PlayTune
    
    jsr SPI_SDCard_SendCommand18    ;starting address of 0x0
    jsr SPI_WaitResult
    cmp #$FE
    beq PlaySongFromSDCard_ReadHaveData
    rts
PlaySongFromSDCard_ReadHaveData:
    ; Read until 0x1C (File Separator) is found. Possibly 0xFF (End of Music), but not checking for this right now.
    PlaySongFromSDCard_readLoop:
        lda #'B'
        jsr print_char_lcd

        jsr SPI_SDCard_ReadByte
        jsr print_hex_lcd

        cmp #$1C  ;file separator
        beq PlaySongFromSDCard_readLoopComplete    ;if we hit a file separator, we're done reading the file

        cmp #$1D    ;PSG (AY) selector
        beq SetPSG_fromSDCard

        ;Check for supported PSG commands - likely a more efficient way of checking for PSG command numbers
        cmp #$00    ;ChA tone period - fine tune
        beq SetPSGRegister_fromSDCard
        cmp #$01    ;ChA tone period - course tune
        beq SetPSGRegister_fromSDCard
        cmp #$02    ;ChB tone period - fine tune
        beq SetPSGRegister_fromSDCard
        cmp #$03    ;ChB tone period - course tune
        beq SetPSGRegister_fromSDCard
        cmp #$04    ;ChC tone period - fine tune
        beq SetPSGRegister_fromSDCard
        cmp #$05    ;ChC tone period - course tune
        beq SetPSGRegister_fromSDCard
        cmp #$08    ;ChA amplitude
        beq SetPSGRegister_fromSDCard
        cmp #$09    ;ChB amplitude
        beq SetPSGRegister_fromSDCard
        cmp #$0A    ;ChC amplitude
        beq SetPSGRegister_fromSDCard

        cmp #$11    ;Delay
        beq SetDelay_fromSDCard

        bra PlaySongFromSDCard_readLoop     ;always loop - end of loop check above, looking for 0x1C

    PlaySongFromSDCard_readLoopComplete:
        jsr SPI_SDCard_SendCommand12
        jsr SPI_WaitResult
    rts
SetPSG_fromSDCard:
    ;read next byte to get the value
    //jsr SPI_SDCard_ReadByte  ;we are in the 0x1D CMD already - next byte is the PSG number (1-4). 1=Left A,B,C. 3=Left D,E,F. 2=Right A,B,C. 4=Right D,E,F.
    jsr SPI_SDCard_ReadByte
    sta SND_PSG
    jmp PlaySongFromSDCard_readLoop
SetPSGRegister_fromSDCard:
    sta SND_CMD
    jsr SPI_SDCard_ReadByte
    sta SND_VAL
    lda SND_PSG
    cmp #$01
    beq SetPSG1_fromSDCard
    cmp #$02
    beq SetPSG2_fromSDCard
    cmp #$03
    beq SetPSG3_fromSDCard
    cmp #$04
    beq SetPSG4_fromSDCard
    cmp #$05
    beq SetPSG5_fromSDCard
    cmp #$06
    beq SetPSG6_fromSDCard    ;shouldn't get to this
    jmp PlaySongFromSDCard_readLoop
SetDelay_fromSDCard:
    ;jsr SPI_SDCard_ReceiveByte  ;get the delay value
    jsr SPI_SDCard_ReadByte
    cmp #$01
    beq SoundTick_fromSDCard
    cmp #$02
    beq SoundTickHalf_fromSDCard
    cmp #$03
    beq SoundTickQuarter_fromSDCard
    cmp #$00
    beq SoundTickMinimal_fromSDCard
    ;no match, shouldn't get here
    jmp PlaySongFromSDCard_readLoop
SetPSG1_fromSDCard:
    lda SND_CMD
    jsr AY1_setreg
    lda SND_VAL
    jsr AY1_writedata        
    ;for now, set PSG2 the same as PSG1 (mirror left channel to right channel) (i.e., don't bra/jmp here, fall into SetPSG2)
    jmp PlaySongFromSDCard_readLoop
SetPSG2_fromSDCard:
    lda SND_CMD
    jsr AY2_setreg
    lda SND_VAL
    jsr AY2_writedata
    jmp PlaySongFromSDCard_readLoop
SetPSG3_fromSDCard:
    lda SND_CMD
    jsr AY3_setreg
    lda SND_VAL
    jsr AY3_writedata
    jmp PlaySongFromSDCard_readLoop
SetPSG4_fromSDCard:
    lda SND_CMD
    jsr AY4_setreg
    lda SND_VAL
    jsr AY4_writedata
    jmp PlaySongFromSDCard_readLoop
SetPSG5_fromSDCard:
    lda SND_CMD
    jsr AY5_setreg
    lda SND_VAL
    jsr AY5_writedata
    jmp PlaySongFromSDCard_readLoop
SetPSG6_fromSDCard:
    lda SND_CMD
    jsr AY6_setreg
    lda SND_VAL
    jsr AY6_writedata
    jmp PlaySongFromSDCard_readLoop
SoundTick_fromSDCard:
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000    
    jmp PlaySongFromSDCard_readLoop
SoundTickHalf_fromSDCard:
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jmp PlaySongFromSDCard_readLoop
SoundTickQuarter_fromSDCard:
    jsr ToneDelay3000
    jsr ToneDelay3000
    jmp PlaySongFromSDCard_readLoop
SoundTickMinimal_fromSDCard:
    jsr ToneDelay
    jmp PlaySongFromSDCard_readLoop
PlayWindowsStartSound:
    
    lda #$FF    ;write
    sta VIA3_DDRA
    sta VIA3_DDRB
    sta VIA2_DDRA

    lda #<SND_RESET
    sta TUNE_PTR_LO
    lda #>SND_RESET
    sta TUNE_PTR_HI
    jsr AY1_PlayTune
    jsr AY2_PlayTune
    jsr AY3_PlayTune
    jsr AY4_PlayTune
    jsr AY5_PlayTune
    jsr AY6_PlayTune

    ;*************** sound to AY1_2 (SND_TONE_E6_FLAT_A) ***************
        lda #<SND_TONE_E6_FLAT_A
        sta TUNE_PTR_LO
        lda #>SND_TONE_E6_FLAT_A
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** sound to AY1_2 (SND_TONE_F1_C) ***************
        lda #<SND_TONE_F1_C
        sta TUNE_PTR_LO
        lda #>SND_TONE_F1_C
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** delay 3 ticks ***************
        
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000

    ;*************** sound to AY1_2 (SND_OFF_A) ***************
        lda #<SND_OFF_A
        sta TUNE_PTR_LO
        lda #>SND_OFF_A
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** sound to AY1_2 (SND_TONE_E5_FLAT_A) ***************
        lda #<SND_TONE_E5_FLAT_A
        sta TUNE_PTR_LO
        lda #>SND_TONE_E5_FLAT_A
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** delay 2 ticks ***************
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000

    ;*************** sound to AY1_2 (SND_TONE_B6_FLAT_A) ***************
        lda #<SND_TONE_B6_FLAT_A
        sta TUNE_PTR_LO
        lda #>SND_TONE_B6_FLAT_A
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** delay 3 ticks ***************
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000

    ;*************** sound to AY1_2 (SND_OFF_ALL) ***************
        lda #<SND_OFF_ALL
        sta TUNE_PTR_LO
        lda #>SND_OFF_ALL
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** sound to AY1_2 (SND_TONE_A6_FLAT_A) ***************
        lda #<SND_TONE_A6_FLAT_A
        sta TUNE_PTR_LO
        lda #>SND_TONE_A6_FLAT_A
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** sound to AY1_2 (SND_OFF_C) ***************
        lda #<SND_OFF_C
        sta TUNE_PTR_LO
        lda #>SND_OFF_C
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** sound to AY1_2 (SND_TONE_A2_FLAT_C) ***************
        lda #<SND_TONE_A2_FLAT_C
        sta TUNE_PTR_LO
        lda #>SND_TONE_A2_FLAT_C
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** delay 5 ticks ***************
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000

    ;*************** sound to AY1_2 (SND_OFF_A) ***************
        lda #<SND_OFF_A
        sta TUNE_PTR_LO
        lda #>SND_OFF_A
        sta TUNE_PTR_HI
        jsr AY1_PlayTune    
        jsr AY2_PlayTune
    ;*************** sound to AY1_2 (SND_TONE_E6_FLAT_A) ***************
        lda #<SND_TONE_E6_FLAT_A
        sta TUNE_PTR_LO
        lda #>SND_TONE_E6_FLAT_A
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** delay 3 ticks ***************
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000

    ;*************** sound to AY1_2 (SND_OFF_ALL) ***************
        lda #<SND_OFF_ALL
        sta TUNE_PTR_LO
        lda #>SND_OFF_ALL
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** sound to AY1_2 (SND_TONE_B6_FLAT_A) ***************
        lda #<SND_TONE_B6_FLAT_A
        sta TUNE_PTR_LO
        lda #>SND_TONE_B6_FLAT_A
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** sound to AY1_2 (SND_TONE_E3_FLAT_B) ***************
        lda #<SND_TONE_E3_FLAT_B
        sta TUNE_PTR_LO
        lda #>SND_TONE_E3_FLAT_B
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** sound to AY1_2 (SND_TONE_B3_FLAT_C) ***************
        lda #<SND_TONE_B3_FLAT_C
        sta TUNE_PTR_LO
        lda #>SND_TONE_B3_FLAT_C
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
    ;*************** delay 8 ticks ***************
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000
        jsr ToneDelay3000

    ;*************** sound to AY1_2_3_4 (off) ***************
        lda #<SND_OFF_ALL
        sta TUNE_PTR_LO
        lda #>SND_OFF_ALL
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune

    rts
PlayTestChords:
    lda #$FF    ;write (out) for all VIAs
    sta VIA3_DDRA
    sta VIA3_DDRB
    sta VIA2_DDRA

    lda #<SND_RESET
    sta TUNE_PTR_LO
    lda #>SND_RESET
    sta TUNE_PTR_HI
    jsr AY1_PlayTune
    jsr AY2_PlayTune
    jsr AY3_PlayTune
    jsr AY4_PlayTune
    jsr AY5_PlayTune
    jsr AY6_PlayTune
    

    lda #<SND_TONE_F6_A
    sta TUNE_PTR_LO
    lda #>SND_TONE_F6_A
    sta TUNE_PTR_HI
    jsr AY1_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_D6_B
    sta TUNE_PTR_LO
    lda #>SND_TONE_D6_B
    sta TUNE_PTR_HI
    jsr AY1_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_A5_SHARP_C
    sta TUNE_PTR_LO
    lda #>SND_TONE_A5_SHARP_C
    sta TUNE_PTR_HI
    jsr AY1_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_G5_A
    sta TUNE_PTR_LO
    lda #>SND_TONE_G5_A
    sta TUNE_PTR_HI
    jsr AY2_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_E5_B
    sta TUNE_PTR_LO
    lda #>SND_TONE_E5_B
    sta TUNE_PTR_HI
    jsr AY2_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_C5_C
    sta TUNE_PTR_LO
    lda #>SND_TONE_C5_C
    sta TUNE_PTR_HI
    jsr AY2_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_OFF_ALL
    sta TUNE_PTR_LO
    lda #>SND_OFF_ALL
    sta TUNE_PTR_HI
    jsr AY1_PlayTune
    jsr AY2_PlayTune

    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_F4_A
    sta TUNE_PTR_LO
    lda #>SND_TONE_F4_A
    sta TUNE_PTR_HI
    jsr AY3_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_D4_B
    sta TUNE_PTR_LO
    lda #>SND_TONE_D4_B
    sta TUNE_PTR_HI
    jsr AY3_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_A3_SHARP_C
    sta TUNE_PTR_LO
    lda #>SND_TONE_A3_SHARP_C
    sta TUNE_PTR_HI
    jsr AY3_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_G3_A
    sta TUNE_PTR_LO
    lda #>SND_TONE_G3_A
    sta TUNE_PTR_HI
    jsr AY4_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_E3_B
    sta TUNE_PTR_LO
    lda #>SND_TONE_E3_B
    sta TUNE_PTR_HI
    jsr AY4_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_TONE_C3_C
    sta TUNE_PTR_LO
    lda #>SND_TONE_C3_C
    sta TUNE_PTR_HI
    jsr AY4_PlayTune
    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    lda #<SND_OFF_ALL
    sta TUNE_PTR_LO
    lda #>SND_OFF_ALL
    sta TUNE_PTR_HI
    jsr AY3_PlayTune
    jsr AY4_PlayTune

    jsr ToneDelayLongFFF0
    jsr ToneDelayLongFFF0

    rts
SND_RESET:
    .BYTE $00, $00           ;ChanA tone period fine tune
    .BYTE $01, $00           ;ChanA tone period coarse tune
    .BYTE $02, $00           ;ChanB tone period fine tune      
    .BYTE $03, $00           ;ChanB tone period coarse tune
    .BYTE $04, $00           ;ChanC tone period fine tune  
    .BYTE $05, $00           ;ChanC tone period coarse tune
    .BYTE $06, $00           ;Noise Period
    .BYTE $07, $38           ;EnableB        ;all channels enabled, IO set to read for both ports
    .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
    .BYTE $09, $0F           ;ChanB amplitude
    .BYTE $0A, $0F           ;ChanC amplitude
    .BYTE $0B, $00           ;Envelope period fine tune
    .BYTE $0C, $00           ;Envelope period coarse tune
    .BYTE $0D, $00           ;Envelope shape cycle
    ;.BYTE $0E, $00           ;IO Port A
    ;.BYTE $0F, $00           ;IO Port B
    .BYTE $FF, $FF           ; EOF
SND_OFF_ALL:
    .BYTE $08, $00           ;ChanA amplitude    0F = fixed, max
    .BYTE $09, $00           ;ChanB amplitude
    .BYTE $0A, $00           ;ChanC amplitude
    .BYTE $FF, $FF                ; EOF
SND_OFF_A:
    .BYTE $08, $00           ;ChanA amplitude    0F = fixed, max
    .BYTE $FF, $FF           ; EOF
SND_OFF_B:
    .BYTE $09, $00           ;ChanB amplitude
    .BYTE $FF, $FF           ; EOF
SND_OFF_C:
    .BYTE $0A, $00           ;ChanC amplitude
    .BYTE $FF, $FF           ; EOF
SND_TONE_100:
    .BYTE $00, $E2           ;ChanA tone period fine tune
    .BYTE $01, $04           ;ChanA tone period coarse tune
    .BYTE $02, $E2           ;ChanB tone period fine tune      
    .BYTE $03, $04           ;ChanB tone period coarse tune
    .BYTE $04, $E2           ;ChanC tone period fine tune  
    .BYTE $05, $04           ;ChanC tone period coarse tune
    .BYTE $07, $38           ;EnableB
    .BYTE $0A, $0F           ;ChanA amplitude    0F = fixed, max
    .BYTE $0B, $0F           ;ChanB amplitude
    .BYTE $0C, $0F           ;ChanC amplitude
    .BYTE $FF, $FF           ; EOF
SND_TONE_500:
    .BYTE $00, $FA           ;ChanA tone period fine tune
    .BYTE $01, $00           ;ChanA tone period coarse tune
    .BYTE $02, $FA           ;ChanB tone period fine tune      
    .BYTE $03, $00           ;ChanB tone period coarse tune
    .BYTE $04, $FA           ;ChanC tone period fine tune  
    .BYTE $05, $00           ;ChanC tone period coarse tune
    .BYTE $06, $00           ;Noise Period
    .BYTE $07, $38           ;EnableB
    .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
    .BYTE $09, $0F           ;ChanB amplitude
    .BYTE $0A, $0F           ;ChanC amplitude
    .BYTE $0B, $00           ;Envelope period fine tune
    .BYTE $0C, $00           ;Envelope period coarse tune
    .BYTE $0D, $00           ;Envelope shape cycle
    .BYTE $FF, $FF           ; EOF
SND_TONE_1K:
    .BYTE $00, $7D           ;ChanA tone period fine tune
    .BYTE $01, $00           ;ChanA tone period coarse tune
    .BYTE $02, $7D           ;ChanB tone period fine tune      
    .BYTE $03, $00           ;ChanB tone period coarse tune
    .BYTE $04, $7D           ;ChanC tone period fine tune  
    .BYTE $05, $00           ;ChanC tone period coarse tune
    .BYTE $07, $38           ;EnableB
    .BYTE $0A, $0F           ;ChanA amplitude    0F = fixed, max
    .BYTE $0B, $0F           ;ChanB amplitude
    .BYTE $0C, $0F           ;ChanC amplitude
    .BYTE $FF, $FF           ; EOF
SND_TONE_5K:
    .BYTE $00, $19           ;ChanA tone period fine tune
    .BYTE $01, $00           ;ChanA tone period coarse tune
    .BYTE $02, $19           ;ChanB tone period fine tune      
    .BYTE $03, $00           ;ChanB tone period coarse tune
    .BYTE $04, $19           ;ChanC tone period fine tune  
    .BYTE $05, $00           ;ChanC tone period coarse tune
    .BYTE $07, $38           ;EnableB
    .BYTE $0A, $0F           ;ChanA amplitude    0F = fixed, max
    .BYTE $0B, $0F           ;ChanB amplitude
    .BYTE $0C, $0F           ;ChanC amplitude
    .BYTE $FF, $FF           ; EOF
SND_TONE_10K:
    .BYTE $00, $0C           ;ChanA tone period fine tune
    .BYTE $01, $00           ;ChanA tone period coarse tune
    .BYTE $02, $0C           ;ChanB tone period fine tune      
    .BYTE $03, $00           ;ChanB tone period coarse tune
    .BYTE $04, $0C           ;ChanC tone period fine tune  
    .BYTE $05, $00           ;ChanC tone period coarse tune
    .BYTE $07, $38           ;EnableB
    .BYTE $0A, $0F           ;ChanA amplitude    0F = fixed, max
    .BYTE $0B, $0F           ;ChanB amplitude
    .BYTE $0C, $0F           ;ChanC amplitude
    .BYTE $FF, $FF           ; EOF
SND_TONE_15K:
    .BYTE $00, $08           ;ChanA tone period fine tune
    .BYTE $01, $00           ;ChanA tone period coarse tune
    .BYTE $02, $08           ;ChanB tone period fine tune      
    .BYTE $03, $00           ;ChanB tone period coarse tune
    .BYTE $04, $08           ;ChanC tone period fine tune  
    .BYTE $05, $00           ;ChanC tone period coarse tune
    .BYTE $07, $38           ;EnableB
    .BYTE $0A, $0F           ;ChanA amplitude    0F = fixed, max
    .BYTE $0B, $0F           ;ChanB amplitude
    .BYTE $0C, $0F           ;ChanC amplitude
    .BYTE $FF, $FF           ; EOF
;Win95 Start
    SND_TONE_B6_FLAT_A:
        .BYTE $00, $43           ;ChanA tone period fine tune
        .BYTE $01, $00           ;ChanA tone period coarse tune
        .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
        .BYTE $FF, $FF                ; EOF
    SND_TONE_A6_FLAT_A:
        .BYTE $00, $4B           ;ChanA tone period fine tune
        .BYTE $01, $00           ;ChanA tone period coarse tune
        .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
        .BYTE $FF, $FF           ; EOF
    SND_TONE_E6_FLAT_A:
        .BYTE $00, $64           ;ChanA tone period fine tune
        .BYTE $01, $00           ;ChanA tone period coarse tune
        .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
        .BYTE $FF, $FF           ; EOF
    SND_TONE_E5_FLAT_A:
        .BYTE $00, $C8           ;ChanA tone period fine tune
        .BYTE $01, $00           ;ChanA tone period coarse tune
        .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
        .BYTE $FF, $FF           ; EOF
    SND_TONE_B3_FLAT_C:
        .BYTE $04, $18           ;ChanC tone period fine tune  
        .BYTE $05, $02           ;ChanC tone period coarse tune
        .BYTE $0A, $0F           ;ChanC amplitude
        .BYTE $FF, $FF           ; EOF
    SND_TONE_E3_FLAT_B:
        .BYTE $02, $23           ;ChanB tone period fine tune      
        .BYTE $03, $03           ;ChanB tone period coarse tune
        .BYTE $09, $0F           ;ChanB amplitude
        .BYTE $FF, $FF           ; EOF
    SND_TONE_A2_FLAT_C:
        .BYTE $04, $B3           ;ChanA tone period fine tune
        .BYTE $05, $04           ;ChanA tone period coarse tune
        .BYTE $0A, $0F           ;ChanC amplitude    0F = fixed, max
        .BYTE $FF, $FF           ; EOF
    SND_TONE_F1_C:
        .BYTE $04, $2F           ;ChanC tone period fine tune  
        .BYTE $05, $0B           ;ChanC tone period coarse tune
        .BYTE $0A, $0F           ;ChanC amplitude
        .BYTE $FF, $FF           ; EOF
;Chords
    SND_TONE_F6_A:
        .BYTE $00, $59
        .BYTE $01, $00
        .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
        .BYTE $FF, $FF
    SND_TONE_D6_B:
        .BYTE $02, $6A
        .BYTE $03, $00
        .BYTE $09, $0F           ;ChanB amplitude
        .BYTE $FF, $FF    
    SND_TONE_A5_SHARP_C:
        .BYTE $04, $86
        .BYTE $05, $00
        .BYTE $0A, $0F           ;ChanC amplitude
        .BYTE $FF, $FF
    SND_TONE_G5_A:
        .BYTE $00, $9F
        .BYTE $01, $00
        .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
        .BYTE $FF, $FF
    SND_TONE_E5_B:
        .BYTE $02, $BD
        .BYTE $03, $00
        .BYTE $09, $0F           ;ChanB amplitude
        .BYTE $FF, $FF    
    SND_TONE_C5_C:
        .BYTE $04, $EE
        .BYTE $05, $00
        .BYTE $0A, $0F           ;ChanC amplitude
        .BYTE $FF, $FF
    SND_TONE_F4_A:
        .BYTE $00, $65
        .BYTE $01, $01
        .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
        .BYTE $FF, $FF
    SND_TONE_D4_B:
        .BYTE $02, $A9
        .BYTE $09, $0F           ;ChanB amplitude
        .BYTE $03, $01
        .BYTE $FF, $FF    
    SND_TONE_A3_SHARP_C:
        .BYTE $04, $18
        .BYTE $05, $02
        .BYTE $0A, $0F           ;ChanC amplitude
        .BYTE $FF, $FF
    SND_TONE_G3_A:
        .BYTE $00, $7D
        .BYTE $01, $02
        .BYTE $08, $0F           ;ChanA amplitude    0F = fixed, max
        .BYTE $FF, $FF
    SND_TONE_E3_B:
        .BYTE $02, $F6
        .BYTE $03, $02
        .BYTE $09, $0F           ;ChanB amplitude
        .BYTE $FF, $FF    
    SND_TONE_C3_C:
        .BYTE $04, $BB
        .BYTE $05, $03
        .BYTE $0A, $0F           ;ChanC amplitude
        .BYTE $FF, $FF
