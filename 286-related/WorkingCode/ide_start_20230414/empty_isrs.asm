; unimplemented isr's...

isr_int_01h:
	mov		al,				0x01
	call	display_int
	iret

isr_int_02h:		
	mov		al,				0x02
	call	display_int
	iret

isr_int_03h:		
	mov		al,				0x03
	call	display_int
	iret

isr_int_05h:		
	mov		al,				0x05
	call	display_int
	iret

isr_int_07h:		
	mov		al,				0x07
	call	display_int
	iret

isr_int_0Bh:		
	mov		al,				0x0b
	call	display_int
	iret

isr_int_0Ch:		
	mov		al,				0x0c
	call	display_int
	iret

isr_int_0Dh:		
	mov		al,				0x0d
	call	display_int
	iret

isr_int_0Eh:		
	mov		al,				0x0e
	call	display_int
	iret

isr_int_0Fh:		
	mov		al,				0x0f
	call	display_int
	iret

isr_int_11h:		
	mov		al,				0x11
	call	display_int
	iret

isr_int_12h:		
	mov		al,				0x12
	call	display_int
	iret

isr_int_14h:		
	mov		al,				0x14
	call	display_int
	iret

isr_int_15h:		
	mov		al,				0x15
	call	display_int
	iret

isr_int_16h:		
	mov		al,				0x16
	call	display_int
	iret

isr_int_17h:		
	mov		al,				0x17
	call	display_int
	iret

isr_int_18h:		
	mov		al,				0x18
	call	display_int
	iret

isr_int_19h:		
	mov		al,				0x19
	call	display_int
	iret

isr_int_1ah:		
	mov		al,				0x1a
	call	display_int
	iret

isr_int_1bh:		
	mov		al,				0x1b
	call	display_int
	iret

isr_int_1ch:		
	mov		al,				0x1c
	call	display_int
	iret

isr_int_1dh:		
	mov		al,				0x1d
	call	display_int
	iret

isr_int_1eh:		
	mov		al,				0x1e
	call	display_int
	iret

isr_int_1fh:		
	mov		al,				0x1f
	call	display_int
	iret

isr_int_20h:		
	mov		al,				0x20
	call	display_int
	iret

isr_int_22h:		
	mov		al,				0x22
	call	display_int
	iret

isr_int_23h:		
	mov		al,				0x23
	call	display_int
	iret

isr_int_24h:	
	mov		al,				0x24
	call	display_int
	iret

isr_int_25h:		
	mov		al,				0x25
	call	display_int
	iret

isr_int_26h:		
	mov		al,				0x26
	call	display_int
	iret

isr_int_27h:		
	mov		al,				0x27
	call	display_int
	iret

isr_int_28h:		
	mov		al,				0x28
	call	display_int
	iret

isr_int_29h:		
	mov		al,				0x29
	call	display_int
	iret

isr_int_2ah:		
	mov		al,				0x2a
	call	display_int
	iret

isr_int_2bh:		
	mov		al,				0x2b
	call	display_int
	iret

isr_int_2ch:
	mov		al,				0x2c
	call	display_int
	iret

isr_int_2dh:		
	mov		al,				0x2d
	call	display_int
	iret

isr_int_2eh:		
	mov		al,				0x2e
	call	display_int
	iret

isr_int_2fh:
	mov		al,				0x2f
	call	display_int
	iret

display_int:
	call	lcd_clear
	push	ax
	mov		al, '!'
	call	print_char
	mov		al, 'i'
	call	print_char
	mov		al, 'r'
	call	print_char
	mov		al, 'q'
	call	print_char
	mov		al, ':'
	call	print_char
	call	lcd_line2
	pop		ax
	call	print_char_hex

	call	play_error_sound
	call	delay
	call	play_error_sound
	call	delay
	call	play_error_sound
	hlt		; temporary