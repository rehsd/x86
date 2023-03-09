; ISA Sound Card
; Author: rehsd
; Modifcation date: 4 March 2023
; Latest update: Initial fire up of 65816 core

; Additional Comments
;
;   Assume 8-bit A,X,Y registers at all times. Any routine that changes this should change it back when complete.
;
;   VIA1    -Port B used for SPI control
;           -Port A is unused/available
;   VIA2    -Port B used for debug LCD
;           -Port A used for PSG5-6 control and interrupt from sound card to host system
;   VIA3    -Port B used for PSG1-4 control
;           -Port A used for common data to all six PSGs
;
;   2 MHz oscillator used for PSGs
;   10 MHz used for sound card core

; To Do:
;   -sd card stream: filter out periodic status bytes (see x86 spi code)

MyCode.65816.asm
.setting "HandleLongBranch", true
//.setting "RegA16", false
//.setting "RegXY16", true


;TO DO
;
;-when changing flags on VIA2, PortA, need to OR or AND instead of setting, as different bits are being used for different purposes
; for example, PA4 is used to raise an interrupt back to the primary system

.org $8000

.include "vars.asm"
.include "utils.asm"
.include "lcd.asm"
.include "sound.asm"
.include "SPI_SDcard.asm"
.include "music.asm"
.include "effects.asm"

reset:
    sei               ;disable interrupts
    cld               ;disable BCD
    clc
    
    xce               ;set native mode

    ;VIA config
    ;Set(1)/Clear(0)|Timer1|Timer2|CB1|CB2|ShiftReg|CA1|CA2
    lda #%01111111	        ; Disable all interrupts
    //sta VIA1_IER
    //sta VIA2_IER
    sta VIA3_IER

    jsr init_lcd
    jsr test_dpram

    jsr init_sound
    
    ;lda #$01
    ;sta SND_ROM_POS3
    ;lda #$7D
    ;sta SND_ROM_POS2
    ;lda #$4F
    ;sta SND_ROM_POS
    ;bra processCMDsCont


    //jsr SPI_SDCard_Testing

    //jsr PlayWindowsStartSound

    cli   ;enable interrupts

    jmp loop_label

loop_label:
    lda CMDtoProcess
    cmp #1
    beq processCMDs
    bra loop_label

test_dpram:
    lda #$31
    sta $6002
    lda #$bd
    sta $6003

    lda #0          ;clear register a for the fun of it

    lda $6002
    jsr print_hex_lcd
    lda $6003
    jsr print_hex_lcd

    rts

CMD1:
    lda #$00
    sta SND_ROM_POS3
    sta SND_ROM_POS2
    sta SND_ROM_POS
    bra processCMDsCont
CMD2:
    lda #$00
    sta SND_ROM_POS3
    lda #$37
    sta SND_ROM_POS2
    lda #$D6
    sta SND_ROM_POS
    bra processCMDsCont
CMD3:
    lda #$00
    sta SND_ROM_POS3
    lda #$41
    sta SND_ROM_POS2
    lda #$2D
    sta SND_ROM_POS
    bra processCMDsCont
CMD4:
    lda #$00
    sta SND_ROM_POS3
    lda #$8F
    sta SND_ROM_POS2
    lda #$2E
    sta SND_ROM_POS
    bra processCMDsCont
CMD5:
    lda #$00
    sta SND_ROM_POS3
    lda #$C3
    sta SND_ROM_POS2
    lda #$94
    sta SND_ROM_POS
    bra processCMDsCont
processCMDs:
    ;Get last read index from $7002-3
    ;Get last written index from $7000-1    (should be >= last read)
    ;Starting with last read index + 4, process commands (every other double-byte and read until last written)
    ;   On first interrupt, last read value will be #$0000, so first read starts at #$7000+#$0000+#$0004 = $7004
    ;   CMD buffer goes to $73FF -- the last command will be at 73FC. If we hit this, cycle back to 7004
    ;Once finished, update last read and processCMDs flag

    //TO DO read actual cmds and process accordingly (loop). For now, just testing with a song playback.
    jsr readFromDPRAM
    jsr print_hex_lcd
    cmp #1
    beq CMD1
    cmp #2
    beq CMD2
    cmp #3
    beq CMD3
    cmp #4
    beq CMD4
    cmp #5
    beq CMD5
    cmp #6
    beq CMD6
    cmp #7
    beq CMD7
    cmp #8
    beq CMD8
    cmp #9
    beq CMD9

    processCMDsCont:
        jsr PlayFromROM

    stz CMDtoProcess
    bra loop_label
CMD6:
    lda #$01
    sta SND_ROM_POS3
    lda #$5A
    sta SND_ROM_POS2
    lda #$12
    sta SND_ROM_POS
    bra processCMDsCont
CMD7:
    lda #$01
    sta SND_ROM_POS3
    lda #$7D
    sta SND_ROM_POS2
    lda #$4F
    sta SND_ROM_POS
    bra processCMDsCont
CMD8:
    lda #$02
    sta SND_ROM_POS3
    lda #$7A
    sta SND_ROM_POS2
    lda #$6B
    sta SND_ROM_POS
    bra processCMDsCont
CMD9:
    lda #$02
    sta SND_ROM_POS3
    lda #$FC
    sta SND_ROM_POS2
    lda #$AC
    sta SND_ROM_POS
    bra processCMDsCont

readFromDPRAM:
    ;$7000-7001     Index of dpram last written by host system
    ;$7002-7003     Index of dpram last read by sound card
    ;$7004-7005     CMD (double-byte)
    ;$7006-7007     DATA (double-byte)
    
    ;This procedure is called from loop_label when an interrupt has been set on the sound card's 65816

    lda $6002           ;on the main system, this address is accessed at $100002
    ;jsr print_hex_lcd
    //jsr print_char_lcd
    rts

irq_label:
    
    phb
    phd
    rep #%00110000    ;16-bit registers
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack


    ;Only the host system can raise an interrupt here... no other sources of interrupts
    ;Read from dpram: last read location
    ;Read next location for command and process until...
    
    sep #%00110000    ;8-bit registers

    lda #1
    sta CMDtoProcess        ;1 = a new command to process

    lda SND_MUSIC_PLAYING
    beq irq_label_out
        ;if currently playing, stop
        lda #1
        sta SND_ABORT_MUSIC

    irq_label_out:
    ;return items from stack
    rep #%00110000    ;16-bit registers
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    pld
    plb

    rti

.org $FFEE
    .word irq_label   //native 16-bit mode interrupt vector

.org $FFFC
    .word reset
    .word irq_label   //emulation interrupt vector


