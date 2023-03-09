ToneDelay:
    pha       ;save current accumulator
    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit

    // lda toneDelayDuration	;counter start - increase number to shorten delay
    lda #$F000
    ToneDelayLoop:
        clc
        adc #01
        bne ToneDelayLoop
    .setting "RegA16", false
    sep #$20
    pla
    rts
ToneDelay3000:
    pha       ;save current accumulator
    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit

    // lda toneDelayDuration	;counter start - increase number to shorten delay
    //lda #$5000        ;Win login, Dream
    
    //lda #$AA00        ;Mario
    lda #$BA00        ;Mario

    //lda #$C700          ;Monkey Island
    //lda #$B000          ;Star Trek Into Darkess, Zelda
    ToneDelay3000Loop:
        clc
        adc #01
        bne ToneDelay3000Loop
    .setting "RegA16", false
    sep #$20
    pla
    rts
ToneDelay0000:
    pha       ;save current accumulator
    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit

    // lda toneDelayDuration	;counter start - increase number to shorten delay
    lda #$0000
    ToneDelay0000Loop:
        clc
        adc #01
        bne ToneDelay0000Loop
    .setting "RegA16", false
    sep #$20
    pla
    rts
ToneDelayLongFFF0:
    pha       ;save current accumulator
    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit

    // lda toneDelayDuration	;counter start - increase number to shorten delay
    lda #$FFF0
    sta $41       ; store high byte
    ToneDelayFFF0Loop:
        clc
        adc #1
        bne ToneDelayFFF0Loop
        clc
        inc $41
        bne ToneDelayFFF0Loop
        
    .setting "RegA16", false
    sep #$20
    pla
    rts
Delay0:
    pha       ;save current accumulator
    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit
    ;lda delayDuration	;counter start - increase number to shorten delay
    lda #0
    Delayloop0:
        clc
        adc #01
        bne Delayloop0
    .setting "RegA16", false
    sep #$20
    pla
    rts
Delay:
    .setting "RegA16", true
    rep #$20            ;set acumulator to 16-bit

    pha       ;save current accumulator
    lda delayDuration	;counter start - increase number to shorten delay
    Delayloop:
        clc
        adc #01
        bne Delayloop
    .setting "RegA16", false
    sep #$20
    pla
    rts