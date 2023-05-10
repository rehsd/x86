diverror_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		call	lcd_clear
		mov		bx,	msg_xcp_diverr
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	play_error_sound
		pop		es
		pop		bx
		iret

overflow_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		call	lcd_clear
		mov		bx,	msg_xcp_overflow
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	play_error_sound
		pop		es
		pop		bx
		iret

invalidop_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		call	lcd_clear
		mov		bx,	msg_xcp_invalidop
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	play_error_sound
		pop		es
		pop		bx
		iret

multiplexcp_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		call	lcd_clear
		mov		bx,	msg_xcp_multi
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	play_error_sound
		pop		es
		pop		bx
		iret

geneneralprot_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		call	lcd_clear
		mov		bx,	msg_xcp_diverr
		call	msg_xcp_genprot				; print message pointed to by bx to LCD
		call	play_error_sound
		pop		es
		pop		bx
		iret

isr_int_11h:				;BIOS Equipment Determination
	;on return:
	;AX contains the following bit flags:
	;
	;|F|E|D|C|B|A|9|8|7|6|5|4|3|2|1|0|  AX
	; | | | | | | | | | | | | | | | `---- IPL diskette installed
	; | | | | | | | | | | | | | | `----- math coprocessor
	; | | | | | | | | | | | | `-------- old PC system board RAM < 256K
	; | | | | | | | | | | | | | `----- pointing device installed (PS/2)
	; | | | | | | | | | | | | `------ not used on PS/2
	; | | | | | | | | | | `--------- initial video mode
	; | | | | | | | | `------------ # of diskette drives, less 1
	; | | | | | | | `------------- 0 if DMA installed
	; | | | | `------------------ number of serial ports
	; | | | `------------------- game adapter installed
	; | | `-------------------- unused, internal modem (PS/2)
	; `----------------------- number of printer ports

	mov		al,	0x11
	call	print_char_hex_spi
	mov		al, ':'
	call	print_char_spi
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi

	mov	ax,	0b00000000_00101110

	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi
	iret
	
isr_int_12h:			;Memory Size Determination
	push	ax
	mov		al,	0x12
	call	print_char_hex_spi
	mov		al, ':'
	call	print_char_spi
	pop		ax
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi
	mov		ax,		640		; number of contiguous 1k memory blocks found at startup
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi
	iret

isr_int_16h:			;Keyboard BIOS Services	
	push	bp		
	mov		bp, sp
	
	push	ax
	call	print_char_newline_spi
	mov		al,	0x16
	call	print_char_hex_spi
	mov		al, ':'
	call	print_char_spi
	pop		ax
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi
	
	.wait_for_keystroke:				;0x00
		cmp		ah,		0x00
		jne		.get_keystroke_status
		
		;on return:
		;AH = keyboard scan code
		;AL = ASCII character or zero if special function key
		
		;testing
		mov		ax,		0x256B
		jmp		.out
	.get_keystroke_status:				;0x01
		cmp		ah,		0x01
		jne		.out
		
		;on return:
		;ZF = 0 if a key pressed (even Ctrl-Break)
		;AX = 0 if no scan code is available
		;AH = scan code
		;AL = ASCII character or zero if special function key
	
		;***add	 word es:[0x046c+2], 0x0fff		;**!! to do - cheating to get back missing timer functionality

		mov		ax, 0
		cmp		ax, ax		; set zero flag
		jmp		.out
	.out:
		push ax			; update flags in stack frame for proper return
		lahf
		; bp + 0 = saved bp
		; bp + 2 = ip
		; bp + 4 = cs
		; bp + 6 = fl
		mov byte [bp + 6], ah
		pop ax
		pop bp
		iret
		; *****************************

isr_int_1ah:			;Read Time From Real Time Clock
	;on return:
	;CF = 0 if successful
	;   = 1 if error, RTC not operating
	;CH = hours in BCD
	;CL = minutes in BCD
	;DH = seconds in BCD
	;DL = 1 if daylight savings time option
	
	push	ax
	mov		al,	0x16
	call	print_char_hex_spi
	mov		al, ':'
	call	print_char_spi
	pop		ax
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi
	
	; ** HOURS **
	mov		al,			0x02		; addr 0x02=hours
	call	spi_read_RTC			; bit 4 = 10s, low nibble 1s
	and		al,			0b00111111
	mov		ch,			al

	; ** MINUTES **
	mov		al,			0x01		; addr 0x01=minutes, high nibble 10s, low nibble 1s
	call	spi_read_RTC
	mov		cl,			al

	; ** SECONDS **
	mov		al,			0x00		; addr 0x00=seconds, high nibble 10s, low nibble 1s
	call	spi_read_RTC
	mov		dh,			al
		
	mov		dl,			0x01

	clc								; clear carry flag

	pushf	;push flags, just in case anything in .out modified flags
	push	ax
	push	es
	push	0x00
	pop		es
	lahf
	mov		es:[flags_debug],	ah
	pop		es
	pop		ax
	push	ax
	call	print_char_newline_spi
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi
	pop		ax
	popf
	retf	2
	;iret
