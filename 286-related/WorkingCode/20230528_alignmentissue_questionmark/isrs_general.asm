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
	; | | | | | | | | | | | | | | | `---- 1 if floppy disk drives installed
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

	push	ax
	mov		al,	0x11
	call	print_char_hex_spi
	mov		al, ':'
	call	print_char_spi
	pop		ax
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi

	push	ds
	call	to0000ds

	;mov	ax,	0b00000000_00100000		;0x0002
	mov		ax, [equipment_list]

	pop		ds

	push	ax
	mov		al, ' '
	call	print_char_spi
	mov		al, ' '
	call	print_char_spi
	mov		al, ' '
	call	print_char_spi
	pop		ax
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

	push	ds
	call	to0000ds
	mov		ax,		[memory_size]		; number of contiguous 1k memory blocks found at startup
	pop		ds

	push	ax
	mov		al, ' '
	call	print_char_spi
	mov		al, ' '
	call	print_char_spi
	mov		al, ' '
	pop		ax
	call	print_char_spi
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi
	iret

isr_int_16h:			;Keyboard BIOS Services	
	push	bp		
	mov		bp, sp
	
	push	ax
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
		mov		ax,		0x3920
		jmp		.out
	.get_keystroke_status:				;0x01
		cmp		ah,		0x01
		jne		.out
		
		;on return:
		;	ZF = 0 if a key pressed (even Ctrl-Break)
		;	AX = 0 if no scan code is available
		;	AH = scan code
		;	AL = ASCII character or zero if special function key

		push	ds
		call	to0000ds


		pop		ds
	
		mov		ax, 0
		cmp		ax, ax		; set zero flag   (0x40)
		jmp		.out
	.out:

		; **** debug int out **********
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
		mov		al, ' '
		call	print_char_spi
		mov		al, ' '
		call	print_char_spi
		mov		al, ' '
		call	print_char_spi
		call	debug_print_interrupt_info_sm
		call	print_char_newline_spi
		pop		ax

		popf
		; *** /debug int out **********
		
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

isr_int_19h:
	;DL = physical drive where boot sector is located
	;output: none
	;track 0, sector 1 is loaded into address 0:7C00 and control is transferred there


	mov		ax,		0x0000			; es:bx = pointer to buffer / destination
	mov		es,		ax
	mov		bx,		0x7c00
	mov		ah,		0x02			; function 0x02
	mov		al,		0x01			; number of sectors to read
	mov		dl,		0x80			; drive 0
	mov		dh,		0x00			; head 0			; MBR
	mov		cl,		0x01			; sector number, 1-based, bottom six bits; cylinder high, top two bits
	mov		ch,		0x00			; cylinder low
	call	ide_read

	jmp		0x0000:0x7c00

isr_int_1ah:			;Read Time From Real Time Clock
	push	bp
	mov		bp,		sp

	push	ax
	mov		al,	0x1a
	call	print_char_hex_spi
	mov		al, ':'
	call	print_char_spi
	pop		ax

	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi

	push	ds
	call	to0000ds

	.read_counter:					; 0x00
		cmp	ah, 0x00
		jne .set_counter

		;on return:
		;	AL = midnight flag, 1 if 24 hours passed since reset
		;	CX = high order word of tick count
		;	DX = low order word of tick count
		;incremented approximately 18.206 times per second
		;at midnight CX:DX is zero

		;!!!! need to implement a timer interrupt for this
		;fake it for now
		call	update_clock_counter		
		mov		cx,	[clock_counter+2]
		mov		dx, [clock_counter]

		jmp	.out
	.set_counter:					; 0x01
		cmp		ah, 0x01
		jne		.read_time
		;CX = high order word of tick count
		;DX = low order word of tick count
		;returns nothing
		;CX:DX should be set to the number of seconds past midnight multiplied by approximately 18.206
		
		mov		[clock_counter+2],		cx
		mov		[clock_counter],		dx
		jmp		.out
	.read_time:						; 0x02
		cmp	ah, 0x02
		jne .set_time

		;on return:
			;CF = 0 if successful, 1 if error or RTC not operating
			;CH = hours in BCD
			;CL = minutes in BCD
			;DH = seconds in BCD
			;DL = 1 if daylight savings time option
	
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
		jmp		.out
	.set_time:						; 0x03
		cmp		ah,			0x03
		jne		.read_date
		;CH = hours in BCD
		;CL = minutes in BCD
		;DH = seconds in BCD
		;DL = 1 if daylight savings time option, 0 if standard time

		;to do update rtc!!!!
		mov		[time+2],	cx
		mov		[time],		dx
		jmp		.out
	.read_date:						; 0x04
		cmp		ah, 0x04
		jne		.set_date
		;on return:
		;	CH = century in BCD (decimal 19 or 20)
		;	CL = year in BCD
		;	DH = month in BCD
		;	DL = day in BCD
		;	CF = 0 if successful, 1 if error or clock not operating

		;faking it for now... need to add SPI call to RTC
		mov		ch,		0b0010_0000		;bcd 20
		mov		cl,		0b0010_0011		;bcd 23
		mov		dh,		0b0000_1001
		mov		dl,		0b0010_0001

		clc
		jmp		.out
	.set_date:						; 0x05
		cmp		ah, 0x05
		jne		.unimplemented
		;CH = century in BCD (decimal 19 or 20)
		;CL = year in BCD
		;DH = month in BCD
		;DL = day in BCD
		;returns nothing
		;all values must be in BCD
		
		mov		[date+2],	cx
		mov		[date],		dx
		jmp		.out
	.unimplemented:
		mov		al, 0x1a
		call	missing_interrupt_tospi
	.out:
		pop		ds
		; **** debug int out **********
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
		mov		al, ' '
		call	print_char_spi
		mov		al, ' '
		call	print_char_spi
		mov		al, ' '
		call	print_char_spi
		call	debug_print_interrupt_info_sm
		call	print_char_newline_spi
		pop		ax
		popf
		; *** /debug int out **********


		; *****************************
		;push bp		; at top
		;mov bp, sp		; at top
	
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
