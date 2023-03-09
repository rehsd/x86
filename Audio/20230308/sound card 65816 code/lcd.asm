.setting "RegA16", false
.setting "RegXY16", false

init_lcd:
    lda #%11111111 
    sta VIA2_DDRB           ; Set all for LCD to output         ;LCD

    jsr lcd_init
    lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font     ;See page 24 of HD44780.pdf
    jsr lcd_instruction
    ;call again for higher clock speed setup (helps when resetting the system)
    lda #%00101000
    jsr lcd_instruction

    lda #%00001110 ; Display on; cursor on; blink off
    jsr lcd_instruction
    lda #%00000110 ; Increment and shift cursor; don't shift display
    jsr lcd_instruction
    lda #%00000001 ; Clear display
    jsr lcd_instruction
    lda #%00001110 ; Display on; cursor on; blink off
    jsr lcd_instruction

    lda #$52    ;'R'
    jsr print_char_lcd
    lda #$65    ;'e'
    jsr print_char_lcd
    lda #$61    ;'a'
    jsr print_char_lcd
    lda #$64    ;'d'
    jsr print_char_lcd
    lda #$79    ;'y'
    jsr print_char_lcd

    lda #%10101000 ; put cursor at position 40
    jsr lcd_instruction

    lda #$3A    ;':'
    jsr print_char_lcd
    lda #$3E    ;'>'
    jsr print_char_lcd
    
    rts
lcd_wait:
  pha
  lda #%11110000  ; LCD data is input
  sta VIA2_DDRB
lcdbusy:
  lda #RW
  sta VIA2_PORTB
  lda #(RW | E)                           
  sta VIA2_PORTB
  lda VIA2_PORTB       ; Read high nibble
  pha             ; and put on stack since it has the busy flag
  lda #RW
  sta VIA2_PORTB
  lda #(RW | E)
  sta VIA2_PORTB
  lda VIA2_PORTB       ; Read low nibble   
  pla             ; Get high nibble off stack
  and #%00001000                            
  bne lcdbusy                              

  lda #RW
  sta VIA2_PORTB
  lda #%11111111  ; LCD data is output
  sta VIA2_DDRB                            
  pla
  
  rts
lcd_init:
    
    
  sep #$20            ;set acumulator to 8-bit

  ;see page 42 of https://eater.net/datasheets/HD44780.pdf
  lda #%00000010 ; Set 4-bit mode
  sta VIA2_PORTB
  ora #E
  sta VIA2_PORTB
  and #%00001111
  sta VIA2_PORTB

  ;rep #$20            ;set acumulator to 16-bit

  rts
lcd_instruction:
  sep #$20            ;set acumulator to 8-bit
  
  ;send an instruction to the 2-line LCD
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr            ; Send high 4 bits
  sta VIA2_PORTB
  ora #E         ; Set E bit to send instruction
  sta VIA2_PORTB
  eor #E         ; Clear E bit
  sta VIA2_PORTB
  pla
  and #%00001111 ; Send low 4 bits
  sta VIA2_PORTB
  ora #E         ; Set E bit to send instruction
  sta VIA2_PORTB
  eor #E         ; Clear E bit
  sta VIA2_PORTB

  ;rep #$20            ;set acumulator to 16-bit

  rts
lcd_clear:
  pha
  lda #%00000001 ; Clear display
  jsr lcd_instruction
  pla
  rts
print_char_lcd:
  sep #$20            ;set acumulator to 8-bit
  
  ;print a character on the 2-line LCD
  jsr lcd_wait
  pha                                      
  lsr
  lsr
  lsr
  lsr             ; Send high 4 bits
  ora #RS         ; Set RS
  sta VIA2_PORTB
  ora #E          ; Set E bit to send instruction
  sta VIA2_PORTB
  eor #E          ; Clear E bit
  sta VIA2_PORTB
  pla
  pha
  and #%00001111  ; Send low 4 bits
  ora #RS         ; Set RS
  sta VIA2_PORTB
  ora #E          ; Set E bit to send instruction
  sta VIA2_PORTB
  eor #E          ; Clear E bit
  sta VIA2_PORTB
  pla

  ;rep #$20            ;set acumulator to 16-bit

  rts


print_hex_lcd:
  
    pha ;a to stack
    phx ;x to stack
    phy ;y to stack

    .setting "RegA16", false
    .setting "RegXY16", false
    sep #$20            ;set acumulator to 8-bit

    ;convert scancode/ascii value/other hex to individual chars and display
    ;e.g., scancode = #$12 (left shift) but want to show '0x12' on LCD
    ;accumulator has the value of the scancode

    sta TMP   ;$65     ;store A so we can keep using original value
    
    ;lda #$30    ;'0'
    ;jsr print_char_lcd
    lda #$78    ;'x'
    jsr print_char_lcd

    ;high nibble
    lda TMP
    and #$F0
    //and #%11110000
    lsr ;shift high nibble to low nibble
    lsr
    lsr
    lsr
    tax
    lda hexOutLookup, x
    jsr print_char_lcd

    ;low nibble
    lda TMP
    and #$0F
    ;and #%00001111
    tax
    lda hexOutLookup, x
    jsr print_char_lcd

    ;.setting "RegA16", false
    ;.setting "RegXY16", false
    ;rep #$30            ;set acumulator to 8-bit

    ;return items from stack
    ply ;stack to y
    plx ;stack to x
    pla ;stack to a
    rts
    
// print_hex_lcd:
//   ;convert scancode/ascii value/other hex to individual chars and display
//   ;e.g., scancode = #$12 (left shift) but want to show '0x12' on LCD
//   ;accumulator has the value of the scancode

//   ;put items on stack, so we can return them
//   pha ;a to stack
//   phx ;x to stack
//   phy ;y to stack

//   sta $4A ;$65     ;store A so we can keep using original value
  
//   ;lda #$30    ;'0'
//   ;jsr print_char_lcd
//   lda #$78    ;'x'
//   jsr print_char_lcd

//   ;high nibble
//   lda $4A
//   and #%0000000011110000
//   lsr ;shift high nibble to low nibble
//   lsr
//   lsr
//   lsr
//   tay
//   lda hexOutLookup, y
//   ;AND #$00FF      ; 16-bit adjustment to code

//   jsr print_char_lcd

//   ;low nibble
//   lda $4A
//   and #%0000000000001111
//   tay
//   lda hexOutLookup, y
//   ;AND #$00FF      ; 16-bit adjustment to code
//   jsr print_char_lcd

//   ;return items from stack
//   ply ;stack to y
//   plx ;stack to x
//   pla ;stack to a

//   rts

.setting "RegA16", false
.setting "RegXY16", false  
hexOutLookup: .byte "0123456789ABCDEF"