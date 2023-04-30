; unimplemented isr's...

isr_int_01h:
	mov		ax,	0
	mov		ds, ax
	mov		ax, 0xf000
	mov		es, ax
	
	mov		di,				0x01
	
	mov		ax,	0x0d
	call	print_char_hex

	mov		ax, ' '
	call	print_char
	mov		ax, ' '
	call	print_char
	mov		ax, '0'
	call	print_char
	mov		ax, '1'
	call	print_char

	mov		ax, ' '
	call	print_char

	call	display_int

	iret

isr_int_02h:		
	mov		di,				0x02
	call	display_int
	iret

isr_int_03h:				;breakpoint
	mov		di,				0x03
	call	display_int
	iret

isr_int_05h:		
	mov		di,				0x05
	call	display_int
	iret

isr_int_07h:		
	mov		di,				0x07
	call	display_int
	iret

isr_int_0Bh:		
	mov		di,				0x0b
	call	display_int
	iret

isr_int_0Ch:		
	mov		di,				0x0c
	call	display_int
	iret

isr_int_0Dh:		
	mov		ax,	0
	mov		ds, ax
	mov		ax, 0xf000
	mov		es, ax
	
	mov		di,				0x0d
	
	mov		ax,	0x0d
	call	print_char_hex

	mov		ax, ' '
	call	print_char
	mov		ax, 'g'
	call	print_char
	mov		ax, 'p'
	call	print_char
	mov		ax, 'f'
	call	print_char

	mov		ax, ' '
	call	print_char

	call	display_int

	iret

isr_int_0Eh:		
	mov		di,				0x0e
	call	display_int
	iret

isr_int_0Fh:		
	mov		di,				0x0f
	call	display_int
	iret

;isr_int_12h:		;Memory Size Determination, see isrs_general.asm


;isr_int_13h:		;disk services, see disk.asm


isr_int_14h:		
	mov		di,				0x14
	call	display_int
	iret

;isr_int_15h:			; temporarily re-purposing in debug.asm
;	mov		di,				0x15
;	call	display_int
;	iret



isr_int_17h:		
	mov		di,				0x17
	call	display_int
	iret

isr_int_18h:		
	mov		di,				0x18
	call	display_int
	iret

isr_int_19h:		
	mov		di,				0x19
	call	display_int
	iret


isr_int_1bh:		
	mov		di,				0x1b
	call	display_int
	iret

isr_int_1ch:		
	mov		di,				0x1c
	call	display_int
	iret

isr_int_1dh:		
	mov		di,				0x1d
	call	display_int
	iret

isr_int_1eh:		
	mov		di,				0x1e
	call	display_int
	iret

isr_int_1fh:		
	mov		di,				0x1f
	call	display_int
	iret

isr_int_20h:		
	mov		di,				0x20
	call	display_int
	iret

isr_int_22h:		
	mov		di,				0x22
	call	display_int
	iret

isr_int_23h:		
	mov		di,				0x23
	call	display_int
	iret

isr_int_24h:	
	mov		di,				0x24
	call	display_int
	iret

isr_int_25h:		
	mov		di,				0x25
	call	display_int
	iret

isr_int_26h:		
	mov		di,				0x26
	call	display_int
	iret

isr_int_27h:		
	mov		di,				0x27
	call	display_int
	iret

isr_int_28h:		
	mov		di,				0x28
	call	display_int
	iret

isr_int_29h:		
	mov		di,				0x29
	call	display_int
	iret

isr_int_2ah:		
	mov		di,				0x2a
	call	display_int
	iret

isr_int_2bh:		
	mov		di,				0x2b
	call	display_int
	iret

isr_int_2ch:
	mov		di,				0x2c
	call	display_int
	iret

isr_int_2dh:		
	mov		di,				0x2d
	call	display_int
	iret

isr_int_2eh:		
	mov		di,				0x2e
	call	display_int
	iret

isr_int_2fh:
	mov		di,				0x2f
	call	display_int
	iret

display_int:
	push	ax
	mov		ax,	0
	mov		ds, ax
	mov		ax, 0xf000
	mov		es, ax

	mov		ax,		di
	call	lcd_clear
	push	ax
	mov		ax, '!'
	call	print_char
	mov		ax, 'i'
	call	print_char
	mov		ax, 'r'
	call	print_char
	mov		ax, 'q'
	call	print_char
	mov		ax, ':'
	call	print_char
	call	lcd_line2
	pop		ax
	call	print_char_hex

	call	play_error_sound
	call	delay
	call	play_error_sound

	pop		ax

	call	debug_print_interrupt_info
	ret