.setting "HandleLongBranch", true

//VIA3 Port A for data
//VIA3 Port B for signals for BC1 and BDIR - PSGs 1-4
//VIA2 Port A for signals for BC1 and BDIR - PSGs 5-6

init_sound:
    lda #$00
    sta audio_data_to_write
    sta SND_MUSIC_PLAYING
    sta SND_ABORT_MUSIC

    lda #$FF        ;write
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

    rts
PlayFromROM:
    ;load the data from ROM in variables

    ;PSG6 IOA0-IOA7 + IOB0-IOB7     --> ROM A0-A15
    ;PSG5 IOA0-IOA2                 --> ROM A16-A18
    ;PSG5 IOB0-IOB7                 --> ROM D0-D7

    ;PSG6 Register 7 = EnableB      --bit7=IOB (IN low Out high) - set *high* so we can write out ROM address on PSG:B    11000000=0xC0
    ;                               --bit6=IOA (IN low Out high) - set *high* so we can write out ROM address on PSG:A
    ;PSG5 Register 7 = EnableB      --bit7=IOB (IN low Out high) - set *low* so we can read ROM data on PSG:B             01000000=0x40
    ;                               --bit6=IOA (IN low Out high) - set *high* so we can write out ROM address on PSG:A

    ;PSG6 Register 14 = PSG I/O Port A    --write address of ROM  to access
    ;PSG6 Register 15 = PSG I/O Port B    --write address of ROM  to access
    ;PSG5 Register 14 = PSG I/O Port A    --write address of ROM  to access
    ;PSG5 Register 15 = PSG I/O Port B    --read data from ROM at supplied ROM address

    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    lda #1
    sta SND_MUSIC_PLAYING

    ;update to read 64 bytes and store in vars, then repeat until FF is read
    
        ;lda #$0E    ;Register = I/O port A - write ROM address to be read 
        ;jsr AY1_setreg
        ;lda #$00    ;start at beginning of ROM
        ;jsr AY1_writedata
        ;lda #$0F    ;Register = I/O port B - read address at previously specified ROM address
        ;jsr AY1_setreg
        ;jsr AY1_readdata    ;result in A register
        ;jsr print_hex_lcd  ;show it on LCD
    
    ;loop through memory and write to variables
    ;last byte of 64 of end marker (FF if no more data for this item)
    ;start at TonePeriodCourseLA and +1 each iteration

    lda #$07    ;Register = Enable
    jsr AY6_setreg
    lda #%11111000    ;B out (high), A out (high), noise disabled, tone enabled = 01000000=40
    jsr AY6_writedata

    lda #$07    ;Register = Enable
    jsr AY5_setreg
    lda #%01111000    ;B in (low), A out (high), noise disabled, tone enabled = 01000000=40
    jsr AY5_writedata

    ldx #$00
    lda #$00
    //sta Sound_ROW   ;start at row 0
    //sta SND_ROM_POS
    //sta SND_ROM_POS2
    //sta SND_ROM_POS3

    ;for now, not using top three bits of ROM address, write all 0's to these bits in the address - will add this support later
    lda #$0E        ;Register = I/O port A - write ROM address to be read 
    jsr AY5_setreg  ;writes A register, which starts at 0 for this loop (i.e., the beginning of the ROM)
    lda #0                      
    jsr AY5_writedata

    // ;for now, not using next eight bits down ROM address, write all 0's to these bits in the address - will add this support later
    // lda #$0F        ;Register = I/O port B - write ROM address to be read 
    // jsr AY6_setreg  ;writes A register, which starts at 0 for this loop (i.e., the beginning of the ROM)
    // lda #0
    // jsr AY6_writedata

    PlayFromROMLoop:
        ;lda #%00000001 ; Clear display
        ;jsr lcd_instruction

        ;for initial testing, only using bottom eight bits of ROM address
        // lda #$0E        ;Register = I/O port A - write ROM address to be read 
        // jsr AY6_setreg  ;writes A register, which starts at 0 for this loop (i.e., the beginning of the ROM)
        // txa ;use x as counter to iterate through ROM
        // clc
        // adc Sound_ROW   ;starts at 0, will increment if more than one sound row
        // jsr print_hex_lcd       ;*************** row ****************************
        // jsr AY6_writedata

        // lda #$0F    ;Register = I/O port B - read address at previously specified ROM address
        // jsr AY5_setreg
        // jsr AY5_readdata    ;result in A register
        
        jsr GetNextValueFromROM

        cmp #$1C  ;file separator
        beq PlayFromROM_Done    ;if we hit a file separator, we're done reading the file

        cmp #$1D    ;PSG (AY) selector
        beq SetPSG

        ;Process supported PSG commands
        cmp #$00    ;ChA tone period - fine tune
        beq SetPSGRegister
        cmp #$01    ;ChA tone period - course tune
        beq SetPSGRegister
        cmp #$02    ;ChB tone period - fine tune
        beq SetPSGRegister
        cmp #$03    ;ChB tone period - course tune
        beq SetPSGRegister
        cmp #$04    ;ChC tone period - fine tune
        beq SetPSGRegister
        cmp #$05    ;ChC tone period - course tune
        beq SetPSGRegister
        cmp #$08    ;ChA amplitude
        beq SetPSGRegister
        cmp #$09    ;ChB amplitude
        beq SetPSGRegister
        cmp #$0A    ;ChC amplitude
        beq SetPSGRegister

        cmp #$11    ;Delay
        beq SetDelay

        ;Check if the song should continue, or if it should be stopped
        lda SND_ABORT_MUSIC
        cmp #1
        beq PlayFromROM_Done

        bra PlayFromROMLoop

    PlayFromROM_Done:
        stz SND_ABORT_MUSIC
        stz SND_MUSIC_PLAYING
        ;*************** sound off ***************
        lda #<SND_OFF_ALL
        sta TUNE_PTR_LO
        lda #>SND_OFF_ALL
        sta TUNE_PTR_HI
        jsr AY1_PlayTune
        jsr AY2_PlayTune
        jsr AY3_PlayTune
        jsr AY4_PlayTune

        ply ;stack to y
        plx ;stack to x
        pla ;stack to a
    rts
SetPSG:
    ;read next byte to get the value
    ;jsr PrintString_Music_SetPSG
    //jsr SPI_SDCard_ReceiveByte  ;we are in the 0x1D CMD already - next byte is the PSG number (1-4). 1=Left A,B,C. 3=Left D,E,F. 2=Right A,B,C. 4=Right D,E,F.
    jsr GetNextValueFromROM
    sta SND_PSG
    ;jsr print_hex_FPGA
    jmp PlayFromROMLoop
SetPSGRegister:
    sta SND_CMD
    jsr GetNextValueFromROM
    sta SND_VAL
    lda SND_PSG
    cmp #$01
    beq SetPSG1
    cmp #$02
    beq SetPSG2
    cmp #$03
    beq SetPSG3
    cmp #$04
    beq SetPSG4
    cmp #$05
    beq SetPSG5
    cmp #$06
    beq SetPSG6
    ;shouldn't get to this
    jmp PlayFromROMLoop
GetNextValueFromROM:
    
    lda #$0E            ;Register = I/O port A - write ROM address to be read 
    jsr AY5_setreg      ;writes A register, which starts at 0 for this loop (i.e., the beginning of the ROM)
    lda SND_ROM_POS3
    jsr AY5_writedata

    lda #$0F            ;Register = I/O port B - write ROM address to be read 
    jsr AY6_setreg      ;writes A register, which starts at 0 for this loop (i.e., the beginning of the ROM)
    lda SND_ROM_POS2
    jsr AY6_writedata

    lda #$0E            ;Register = I/O port A - write ROM address to be read 
    jsr AY6_setreg      ;writes A register, which starts at 0 for this loop (i.e., the beginning of the ROM)
    lda SND_ROM_POS
    jsr AY6_writedata

    lda #$0F            ;Register = I/O port B - read address at previously specified ROM address
    jsr AY5_setreg
    jsr AY5_readdata    ;result in A register

    ;increment the read position, using three bytes to track address    
    inc SND_ROM_POS
    bne gnv_out
    inc SND_ROM_POS2
    bne gnv_out
    inc SND_ROM_POS3

    gnv_out:
    rts
SetPSG1:
    lda SND_CMD
    jsr AY1_setreg
    lda SND_VAL
    jsr AY1_writedata        
    jmp PlayFromROMLoop
SetPSG2:
    lda SND_CMD
    jsr AY2_setreg
    lda SND_VAL
    jsr AY2_writedata
    jmp PlayFromROMLoop
SetPSG3:
    lda SND_CMD
    jsr AY3_setreg
    lda SND_VAL
    jsr AY3_writedata
    jmp PlayFromROMLoop
SetPSG4:
    lda SND_CMD
    jsr AY4_setreg
    lda SND_VAL
    jsr AY4_writedata
    jmp PlayFromROMLoop
SetPSG5:
    lda SND_CMD
    jsr AY5_setreg
    lda SND_VAL
    jsr AY5_writedata
    jmp PlayFromROMLoop
SetPSG6:
    lda SND_CMD
    jsr AY6_setreg
    lda SND_VAL
    jsr AY6_writedata
    jmp PlayFromROMLoop
SetDelay:
    ;jsr SPI_SDCard_ReceiveByte  ;get the delay value
    jsr GetNextValueFromROM
    cmp #$01
    beq SoundTick
    cmp #$02
    beq SoundTickHalf
    cmp #$03
    beq SoundTickQuarter
    cmp #$00
    beq SoundTickMinimal
    jmp PlayFromROMLoop
SoundTick:
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jmp PlayFromROMLoop
SoundTickHalf:
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jsr ToneDelay3000
    jmp PlayFromROMLoop
SoundTickQuarter:
    jsr ToneDelay3000
    jsr ToneDelay3000
    jmp PlayFromROMLoop
SoundTickMinimal:
    jsr ToneDelay
    jmp PlayFromROMLoop

;The following six AYx sections could be consolidated and more dynamic, using a parameter to specify which AY is active (rather than having four unique sets of routines).
;AY1:
    AY1_PlayTune:
        ldy #0
    AY1_play_loop:
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY1_play_next
        rts
    AY1_play_next:
        jsr AY1_setreg
        iny
        lda (TUNE_PTR_LO), Y         ;y+1, so this is TUNE_PTR_HIGH
        cmp #$FF
        bne AY1_play_next2
        rts
    AY1_play_next2:
        jsr AY1_writedata
        iny
        jmp AY1_play_loop
        rts
    AY1_setreg:
        jsr AY1_inactive     ; NACT
        sta VIA3_PORTA
        jsr AY1_latch        ; INTAK
        jsr AY1_inactive     ; NACT
        rts
    AY1_writedata:
        jsr AY1_inactive     ; NACT
        sta VIA3_PORTA
        jsr AY1_write           ; DWS
        jsr AY1_inactive
        rts
    AY1_inactive:        ; NACT
        ; BDIR  LOW
        ; BC1   LOW
        phx         
        ldx #0     ;A9 high to disable AY -- when adding second AY, will need to set its A9 low (on different port)
        stx VIA3_PORTB
        plx         
        rts
    AY1_latch:           ; INTAK
        ; BDIR  HIGH
        ; BC1   HIGH
        phx         
        ldx #(AY1_BDIR | AY1_BC1);  AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        stx VIA3_PORTB
        plx         
        rts
    AY1_write:           ; DWS
        ; BDIR  HIGH
        ; BC1   LOW
        phx         
        ldx #(AY1_BDIR) ;AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        stx VIA3_PORTB
        plx         
        rts
    AY1_readdata:
        phx
        jsr AY1_inactive
        ldx #$00    ;Read
        stx VIA3_DDRA
        jsr AY1_read
        lda VIA3_PORTA          ;value retrieved from PSG
        ldx #$FF                ;Write
        stx VIA3_DDRA
        jsr AY1_inactive
        plx
        rts
    AY1_read:           ; DTB
        ; BDIR  LOW
        ; BC1   HIGH
        phx
        ldx #(AY1_BC1)
        stx VIA3_PORTB
        plx
        rts
;AY2:
    AY2_PlayTune:
        ldy #0
    AY2_play_loop:
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY2_play_next
        rts
    AY2_play_next:
        jsr AY2_setreg
        iny
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY2_play_next2
        rts
    AY2_play_next2:
        jsr AY2_writedata
        iny
        jmp AY2_play_loop
        rts
    AY2_setreg:
        jsr AY2_inactive     ; NACT
        //sep #$20            ;set acumulator to 8-bit
        sta VIA3_PORTA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY2_latch        ; INTAK
        jsr AY2_inactive     ; NACT
        rts
    AY2_writedata:
        jsr AY2_inactive     ; NACT
        //sep #$20            ;set acumulator to 8-bit
        sta VIA3_PORTA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY2_write           ; DWS
        jsr AY2_inactive
        rts
    AY2_inactive:        ; NACT
        ; BDIR  LOW
        ; BC1   LOW
        phx         
        ldx #0     ;A9 high to disable AY -- when adding second AY, will need to set its A9 low (on different port)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY2_latch:           ; INTAK
        ; BDIR  HIGH
        ; BC1   HIGH
        phx   
        ldx #(AY2_BDIR | AY2_BC1);  AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY2_write:           ; DWS
        ; BDIR  HIGH
        ; BC1   LOW
        phx         
        ldx #(AY2_BDIR) ;AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY2_readdata:
        phx
        jsr AY2_inactive
        ldx #$00    ;Read
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_DDRA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY2_read


        //sep #$20            ;set acumulator to 8-bit
        lda VIA3_PORTA
        ldx #$FF    ;Write
        stx VIA3_DDRA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY2_inactive
        plx
        rts
    AY2_read:           ; DTB
        ; BDIR  LOW
        ; BC1   HIGH
        phx
        ldx #(AY2_BC1)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx
        rts
;AY3:
    AY3_PlayTune:
        ldy #0
    AY3_play_loop:
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY3_play_next
        rts
    AY3_play_next:
        jsr AY3_setreg
        iny
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY3_play_next2
        rts
    AY3_play_next2:
        jsr AY3_writedata
        iny
        jmp AY3_play_loop
        rts
    AY3_setreg:
        jsr AY3_inactive     ; NACT
        //sep #$20            ;set acumulator to 8-bit
        sta VIA3_PORTA      
        // rep #$20            ;set acumulator to 16-bit
        jsr AY3_latch        ; INTAK
        jsr AY3_inactive     ; NACT
        rts
    AY3_writedata:
        jsr AY3_inactive     ; NACT
        //sep #$20            ;set acumulator to 8-bit
        sta VIA3_PORTA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY3_write           ; DWS
        jsr AY3_inactive
        rts
    AY3_inactive:        ; NACT
        ; BDIR  LOW
        ; BC1   LOW
        phx         
        ldx #0     ;A9 high to disable AY -- when adding second AY, will need to set its A9 low (on different port)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY3_latch:           ; INTAK
        ; BDIR  HIGH
        ; BC1   HIGH
        phx         
        ldx #(AY3_BDIR | AY3_BC1);  AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY3_write:           ; DWS
        ; BDIR  HIGH
        ; BC1   LOW
        phx         
        ldx #(AY3_BDIR) ;AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY3_readdata:
        phx
        jsr AY3_inactive
        ldx #$00    ;Read
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_DDRA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY3_read

        //sep #$20            ;set acumulator to 8-bit
        lda VIA3_PORTA
        ldx #$FF    ;Write
        stx VIA3_DDRA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY3_inactive
        plx
        rts
    AY3_read:           ; DTB
        ; BDIR  LOW
        ; BC1   HIGH
        phx
        ;ldx #(AY3_BC1 | AY2_A9_B)
        ldx #(AY3_BC1)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx
        rts
;AY4:
    AY4_PlayTune:
        ldy #0
    AY4_play_loop:
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY4_play_next
        rts
    AY4_play_next:
        jsr AY4_setreg
        iny
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY4_play_next2
        rts
    AY4_play_next2:
        jsr AY4_writedata
        iny
        jmp AY4_play_loop
        rts
    AY4_setreg:
        jsr AY4_inactive     ; NACT
        //sep #$20            ;set acumulator to 8-bit
        sta VIA3_PORTA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY4_latch        ; INTAK
        jsr AY4_inactive     ; NACT
        rts
    AY4_writedata:
        jsr AY4_inactive     ; NACT
        //sep #$20            ;set acumulator to 8-bit
        sta VIA3_PORTA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY4_write           ; DWS
        jsr AY4_inactive
        rts
    AY4_inactive:        ; NACT
        ; BDIR  LOW
        ; BC1   LOW
        phx         
        ldx #0     ;A9 high to disable AY -- when adding second AY, will need to set its A9 low (on different port)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY4_latch:           ; INTAK
        ; BDIR  HIGH
        ; BC1   HIGH
        phx         
        ldx #(AY4_BDIR | AY4_BC1);  AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY4_write:           ; DWS
        ; BDIR  HIGH
        ; BC1   LOW
        phx         
        ldx #(AY4_BDIR) ;AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY4_readdata:
        phx
        jsr AY4_inactive
        ldx #$00    ;Read
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_DDRA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY4_read

        lda VIA3_PORTA
        ldx #$FF    ;Write
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_DDRA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY4_inactive
        plx
        rts
    AY4_read:           ; DTB
        ; BDIR  LOW
        ; BC1   HIGH
        phx
        ;ldx #(AY4_BC1 | AY1_A9_B)
        ldx #(AY4_BC1)
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_PORTB
        // rep #$20            ;set acumulator to 16-bit
        plx
        rts
;AY5:
    AY5_PlayTune:
        ldy #0
    AY5_play_loop:
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY5_play_next
        rts
    AY5_play_next:
        jsr AY5_setreg
        iny
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY5_play_next2
        rts
    AY5_play_next2:
        jsr AY5_writedata
        iny
        jmp AY5_play_loop
        rts
    AY5_setreg:
        jsr AY5_inactive     ; NACT
        //sep #$20            ;set acumulator to 8-bit
        sta VIA3_PORTA      
        // rep #$20            ;set acumulator to 16-bit
        jsr AY5_latch        ; INTAK
        jsr AY5_inactive     ; NACT
        rts
    AY5_writedata:
        jsr AY5_inactive     ; NACT
        //sep #$20            ;set acumulator to 8-bit
        sta VIA3_PORTA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY5_write           ; DWS
        jsr AY5_inactive
        rts
    AY5_inactive:        ; NACT
        ; BDIR  LOW
        ; BC1   LOW
        phx         
        ldx #0     ;A9 high to disable AY -- when adding second AY, will need to set its A9 low (on different port)
        //sep #$20            ;set acumulator to 8-bit
        //stx VIA3_PORTB
        stx VIA2_PORTA
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY5_latch:           ; INTAK
        ; BDIR  HIGH
        ; BC1   HIGH
        phx         
        ldx #(AY5_BDIR | AY5_BC1);  AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        //sep #$20            ;set acumulator to 8-bit
        //stx VIA3_PORTB
        stx VIA2_PORTA
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY5_write:           ; DWS
        ; BDIR  HIGH
        ; BC1   LOW
        phx         
        ldx #(AY5_BDIR) ;AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        //sep #$20            ;set acumulator to 8-bit
        //stx VIA3_PORTB
        stx VIA2_PORTA
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY5_readdata:
        phx
        jsr AY5_inactive
        ldx #$00    ;Read
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_DDRA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY5_read

        //sep #$20            ;set acumulator to 8-bit
        lda VIA3_PORTA
        ldx #$FF    ;Write
        stx VIA3_DDRA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY5_inactive
        plx
        rts
    AY5_read:           ; DTB
        ; BDIR  LOW
        ; BC1   HIGH
        phx
        ldx #(AY5_BC1)
        //sep #$20            ;set acumulator to 8-bit
        //stx VIA3_PORTB
        stx VIA2_PORTA
        // rep #$20            ;set acumulator to 16-bit
        plx
        rts
;AY6:
    AY6_PlayTune:
        ldy #0
    AY6_play_loop:
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY6_play_next
        rts
    AY6_play_next:
        jsr AY6_setreg
        iny
        lda (TUNE_PTR_LO), Y
        cmp #$FF
        bne AY6_play_next2
        rts
    AY6_play_next2:
        jsr AY6_writedata
        iny
        jmp AY6_play_loop
        rts
    AY6_setreg:
        jsr AY6_inactive     ; NACT
        //sep #$20            ;set acumulator to 8-bit
        sta VIA3_PORTA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY6_latch        ; INTAK
        jsr AY6_inactive     ; NACT
        rts
    AY6_writedata:
        jsr AY6_inactive     ; NACT
        //sep #$20            ;set acumulator to 8-bit
        sta VIA3_PORTA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY6_write           ; DWS
        jsr AY6_inactive
        rts
    AY6_inactive:        ; NACT
        ; BDIR  LOW
        ; BC1   LOW
        phx         
        ldx #0     ;A9 high to disable AY -- when adding second AY, will need to set its A9 low (on different port)
        //sep #$20            ;set acumulator to 8-bit
        //stx VIA3_PORTB
        stx VIA2_PORTA
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY6_latch:           ; INTAK
        ; BDIR  HIGH
        ; BC1   HIGH
        phx         
        ldx #(AY6_BDIR | AY6_BC1);  AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        //sep #$20            ;set acumulator to 8-bit
        //stx VIA3_PORTB
        stx VIA2_PORTA
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY6_write:           ; DWS
        ; BDIR  HIGH
        ; BC1   LOW
        phx         
        ldx #(AY6_BDIR) ;AY_A9_B low to enable AY -- when adding second AY, will need to set its A9 high here to disable it (on different port)
        //sep #$20            ;set acumulator to 8-bit
        //stx VIA3_PORTB
        stx VIA2_PORTA
        // rep #$20            ;set acumulator to 16-bit
        plx         
        rts
    AY6_readdata:
        phx
        jsr AY6_inactive
        ldx #$00    ;Read
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_DDRA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY6_read

        lda VIA3_PORTA
        ldx #$FF    ;Write
        //sep #$20            ;set acumulator to 8-bit
        stx VIA3_DDRA
        // rep #$20            ;set acumulator to 16-bit
        jsr AY6_inactive
        plx
        rts
    AY6_read:           ; DTB
        ; BDIR  LOW
        ; BC1   HIGH
        phx
        ldx #(AY6_BC1)
        //sep #$20            ;set acumulator to 8-bit
        //stx VIA3_PORTB
        stx VIA2_PORTA
        // rep #$20            ;set acumulator to 16-bit
        plx
        rts
