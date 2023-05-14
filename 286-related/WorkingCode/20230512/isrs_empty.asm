; unimplemented isr's...

isr_int_01h:
	push	di
	mov		di,				0x01
	jmp		display_int

isr_int_02h:		
	push	di
	mov		di,				0x02
	jmp		display_int

isr_int_03h:				;breakpoint
	push	di
	mov		di,				0x03
	jmp		display_int

isr_int_05h:		
	push	di
	mov		di,				0x05
	jmp		display_int

isr_int_07h:		
	push	di
	mov		di,				0x07
	jmp		display_int

isr_int_0Bh:		
	push	di
	mov		di,				0x0b
	jmp		display_int

isr_int_0Ch:		
	push	di
	mov		di,				0x0c
	jmp		display_int

isr_int_0Dh:		
	push	di
	mov		di,				0x0d
	jmp		display_int

isr_int_0Eh:		
	push	di
	mov		di,				0x0e
	jmp		display_int

isr_int_0Fh:		
	push	di
	mov		di,				0x0f
	jmp		display_int

;isr_int_12h:		;Memory Size Determination, see isrs_general.asm

;isr_int_13h:		;disk services, see disk.asm

isr_int_14h:		
	push	di
	mov		di,				0x14
	jmp		display_int

isr_int_15h:			; previous: temporarily re-purposing in debug.asm
	push	di
	mov		di,				0x15
	jmp		display_int

isr_int_17h:		
	push	di
	mov		di,				0x17
	jmp		display_int

isr_int_18h:		
	push	di
	mov		di,				0x18
	jmp		display_int

isr_int_19h:		
	push	di
	mov		di,				0x19
	jmp		display_int



isr_int_1bh:		
	push	di
	mov		di,				0x1b
	jmp		display_int

isr_int_1ch:		
	push	di
	mov		di,				0x1c
	jmp		display_int

isr_int_1dh:		
	push	di
	mov		di,				0x1d
	jmp		display_int

isr_int_1eh:		
	push	di
	mov		di,				0x1e
	jmp		display_int

isr_int_1fh:		
	push	di
	mov		di,				0x1f
	jmp		display_int

isr_int_20h:		
	push	di
	mov		di,				0x20
	jmp		display_int

dos_services_isr:		; interrupt 0x21
	push	di
	mov		di,				0x21
	jmp		display_int
	
isr_int_22h:		
	push	di
	mov		di,				0x22
	jmp		display_int

isr_int_23h:		
	push	di
	mov		di,				0x23
	jmp		display_int

isr_int_24h:	
	push	di
	mov		di,				0x24
	jmp		display_int

isr_int_25h:		
	push	di
	mov		di,				0x25
	jmp		display_int

isr_int_26h:		
	push	di
	mov		di,				0x26
	jmp		display_int

isr_int_27h:		
	push	di
	mov		di,				0x27
	jmp		display_int

isr_int_28h:		
	push	di
	mov		di,				0x28
	jmp		display_int

isr_int_29h:		
	push	di
	mov		di,				0x29
	jmp		display_int

isr_int_2ah:		
	push	di
	mov		di,				0x2a
	jmp		display_int

isr_int_2bh:		
	push	di
	mov		di,				0x2b
	jmp		display_int

isr_int_2ch:
	push	di
	mov		di,				0x2c
	jmp		display_int

isr_int_2dh:		
	push	di
	mov		di,				0x2d
	jmp		display_int

isr_int_2eh:		
	push	di
	mov		di,				0x2e
	jmp		display_int

isr_int_2fh:
	push	di
	mov		di,				0x2f
	jmp		display_int

display_int:
	push	ax
	mov		ax,	0
	mov		ds, ax
	mov		ax, 0xf000
	mov		es, ax

	call	lcd_clear
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
	
	mov		ax,		di

	call	print_char_hex
	call	debug_print_intnum
	call	play_error_sound
	call	delay
	call	play_error_sound
	call	debug_print_interrupt_info
	
	pop		ax
	pop		di
	iret
