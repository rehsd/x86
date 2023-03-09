;Comments
    ;SPI SD Card routines
    ;Using HiLetgo Micro SD TF Card Reader - https://www.amazon.com/gp/product/B07BJ2P6X6
    ;
    ;SPI LED example from https://github.com/rehsd/VGA-6502/blob/main/6502%20Assembly/PCB_ROM_20211008.s
    ;Core logic adapted from George Foot's awesome page at https://hackaday.io/project/174867-reading-sd-cards-on-a-65026522-computer
    ;
    ;All timing / delays based on onboard 10 MHz 65816. May need to be adjusted if using another clock speed.
    ;
    ;https://developpaper.com/sd-card-command-details/
    ;https://www.kingston.com/datasheets/SDCIT-specsheet-64gb_en.pdf
    ;
    ;In var.asm:
    ;VIA1 PORTB - SPI SD Card data and commands (PORTA unused)
    ;SPI_MISO        = %00000001     
    ;SPI_MOSI        = %00000010     
    ;SPI_SCK         = %00000100     
    ;SPI_CS          = %10000000 

SPI_SDCard_Testing:
    jsr SPI_SDCard_Init
    
    lda #'Y'
    jsr print_char_lcd

    jsr PlaySongFromSDCard

    lda #'Z'
    jsr print_char_lcd

    rts
SPI_SDCard_Init:
    lda #(SPI_CS | SPI_SCK | SPI_MOSI)      ;SPI_MISO is input
    sta VIA1_DDRB  ;control


    lda #(SPI_CS | SPI_MOSI)
    ldx #160            ;80 full clock cycles to give card time to initiatlize

    init_loop:
        eor #SPI_SCK
        sta VIA1_PORTB
        dex
        bne init_loop

    try00:
        lda #<cmd0_bytes
        sta zp_sd_cmd_address
        lda #>cmd0_bytes
        sta zp_sd_cmd_address+1
        jsr SPI_SDCard_SendCommand
        ; Expect status response $01 (not initialized)
        cmp #$01
        bne try00

    jsr DelayC0

    try08:
        lda #<cmd8_bytes
        sta zp_sd_cmd_address
        lda #>cmd8_bytes
        sta zp_sd_cmd_address+1
        jsr SPI_SDCard_SendCommand
        ; Expect status response $01 (not initialized)
        cmp #$01
        bne try08

        jsr SPI_SDCard_ReadByte
        jsr SPI_SDCard_ReadByte
        jsr SPI_SDCard_ReadByte
        jsr SPI_SDCard_ReadByte

    try55:
        lda #<cmd55_bytes
        sta zp_sd_cmd_address
        lda #>cmd55_bytes
        sta zp_sd_cmd_address+1
        jsr SPI_SDCard_SendCommand
        ; Expect status response $01 (not initialized)
        cmp #$01
        bne try55

    try41:
        lda #<cmd41_bytes
        sta zp_sd_cmd_address
        lda #>cmd41_bytes
        sta zp_sd_cmd_address+1
        jsr SPI_SDCard_SendCommand
        ; Expect status response $00 (initialized)
        cmp #$00
        bne try55
    ;init complete    
    rts
SPI_SDCard_SendCommand:

  ldx #0                            //TO DO not needed?
  lda (zp_sd_cmd_address,x)         //TO DO not needed?

  lda #SPI_MOSI           ; pull CS low to begin command
  sta VIA1_PORTB

  ldy #0
  lda (zp_sd_cmd_address),y    ; command byte
  jsr SPI_SDCard_WriteByte
  ldy #1
  lda (zp_sd_cmd_address),y    ; data 1
  jsr SPI_SDCard_WriteByte
  ldy #2
  lda (zp_sd_cmd_address),y    ; data 2
  jsr SPI_SDCard_WriteByte
  ldy #3
  lda (zp_sd_cmd_address),y    ; data 3
  jsr SPI_SDCard_WriteByte
  ldy #4
  lda (zp_sd_cmd_address),y    ; data 4
  jsr SPI_SDCard_WriteByte
  ldy #5
  lda (zp_sd_cmd_address),y    ; crc
  jsr SPI_SDCard_WriteByte

  jsr SPI_WaitResult
  pha

  ; End command
  lda #(SPI_CS | SPI_MOSI)   ; set CS high again
  sta VIA1_PORTB

  pla   ; restore result code
  rts
SPI_SDCard_WriteByte:
  ; Tick the clock 8 times with descending bits on MOSI
  ; SD communication is mostly half-duplex so we ignore anything it sends back here
    ldx #8                      ; send 8 bits
    writebyte_loop:
    asl                         ; shift next bit into carry
    tay                         ; save remaining bits for later
    lda #0
    bcc sendbit                ; if carry clear, don't set MOSI for this bit
    ora #SPI_MOSI

    sendbit:
        sta VIA1_PORTB                   ; set MOSI (or not) first with SCK low
        eor #SPI_SCK
        sta VIA1_PORTB                   ; raise SCK keeping MOSI the same, to send the bit
        tya                         ; restore remaining bits to send
        dex
        bne writebyte_loop                   ; loop if there are more bits to send
    rts
SPI_WaitResult:
  ; Wait for the SD card to return something other than $ff
  jsr SPI_SDCard_ReadByte
  cmp #$ff
  beq SPI_WaitResult
  rts
SPI_SDCard_ReadByte:
  ; Enable the card and tick the clock 8 times with MOSI high, 
  ; capturing bits from MISO and returning them

    ldx #8                      ; we'll read 8 bits
    readByteLoop:
        lda #SPI_MOSI                ; enable card (CS low), set MOSI (resting state), SCK low
        sta VIA1_PORTB
        lda #(SPI_MOSI | SPI_SCK)       ; toggle the clock high
        sta VIA1_PORTB

        lda VIA1_PORTB                   ; read next bit
        and #SPI_MISO

        clc                         ; default to clearing the bottom bit
        beq readByteBitNotSet              ; unless MISO was set
        sec                         ; in which case get ready to set the bottom bit
    readByteBitNotSet:
        tya                         ; transfer partial result from Y
        rol                         ; rotate carry bit into read result
        tay                         ; save partial result back to Y

        dex                         ; decrement counter
        bne readByteLoop                   ; loop if we need to read more bits
  rts
SPI_SDCard_SendCommand12:
    ;.cmd18 ; READ_MULTIPLE_BLOCK
    lda #<cmd12_bytes
    sta zp_sd_cmd_address
    lda #>cmd12_bytes
    sta zp_sd_cmd_address+1
    jsr SPI_SDCard_SendCommand
    ;cmp #$01
    ;bne Initfailed
    rts  
SPI_SDCard_SendCommand18:
    ;.cmd18 ; READ_MULTIPLE_BLOCK
    lda #<cmd18_bytes
    sta zp_sd_cmd_address
    lda #>cmd18_bytes
    sta zp_sd_cmd_address+1
    jsr SPI_SDCard_SendCommand
    ;cmp #$01
    ;bne Initfailed
    rts
Init_Failure:
    lda #'X'
    jsr print_char_lcd
    stp     //just give up and quit :)
;Command sequences
    cmd0_bytes    ;0x40 + command number    ;GO_IDLE_STATE
    .byte $40, $00, $00, $00, $00, $95
    cmd1_bytes                              ;SEND_OP_COND
    .byte $41, $00, $00, $00, $00, $F9
    cmd8_bytes                              ;SEND_IF_COND
    .byte $48, $00, $00, $01, $aa, $87
    cmd12_bytes                             ;STOP_TRANSMISSION
    .byte $4C, $00, $00, $00, $00, $61    
    cmd18_bytes                             ;READ_MULTIPLE_BLOCK, starting at 0x0
    .byte $52, $00, $00, $00, $00, $E1
    cmd41_bytes                             ;SD_SEND_OP_COND
    .byte $69, $40, $00, $00, $00, $77
    cmd55_bytes                             ;APP_CMD
    .byte $77, $00, $00, $00, $00, $65
DelayC0:
    ;Simple delay routine. Counts from 0 to 65535 for the delay.  https://gist.github.com/superjamie/fd80fabadf39199c97de400213f614e9
    pha
    //TO DO Adjust timer value when using faster processor clock
    lda #$FE	  ;counter start - increase number to shorten delay
    sta SPI_Timer       ; store high byte

    DelayC0Loop:
        adc #01
        bne DelayC0Loop
        clc
        inc SPI_Timer
        bne DelayC0Loop
        clc
    pla
    rts