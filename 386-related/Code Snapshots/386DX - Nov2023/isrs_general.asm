diverror_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		;call	lcd_clear
		;mov		bx,	msg_xcp_diverr
		;call	print_message_lcd				; print message pointed to by bx to LCD
		;call	play_error_sound
		pop		es
		pop		bx
		iret

overflow_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		;call	lcd_clear
		;mov		bx,	msg_xcp_overflow
		;call	print_message_lcd				; print message pointed to by bx to LCD
		;call	play_error_sound
		pop		es
		pop		bx
		iret

invalidop_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		;call	lcd_clear
		;mov		bx,	msg_xcp_invalidop
		;call	print_message_lcd				; print message pointed to by bx to LCD
		;call	play_error_sound
		pop		es
		pop		bx
		iret

geneneralprot_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		;call	lcd_clear
		;mov		bx,	msg_xcp_diverr
		;call	msg_xcp_genprot				; print message pointed to by bx to LCD
		;call	play_error_sound
		pop		es
		pop		bx
		iret

isr_int_08h:			; timer
	; should be generated 18.2 times per second by the VIA
	; updates BIOS data area (clock_counter @ 40:6c)

	ds0000
	push	ax
	inc		word [VIA1_T1_count]	; track how many times this interrupt has occured
	mov		ax, [VIA1_T1_count]
	cmp		ax, VIA1_T_CMP			; See notes in _data.asm - this count of interrupts should match desired target of 18.2 times per second for the check below
							
	jl		.under
		clc
		add	word [clock_counter],	0x0001			; inc doesn't modify carry flag
		adc	word [clock_counter+2],	0x0000
		mov	word [VIA1_T1_count],	0x0000
		
		;in		al,			VIA1_T1C_L				; read T1C_L to clear VIA interrupt
		mov		ax,			VIA1_TIMER				; set high timer byte to clear VIA interrupt 
		xchg	al, ah								; the read of T1C_L later should also reset the VIA interrupt, 
		out		VIA1_T1C_H,	al						; but removing this line results in issues (research needed)
		
	.under:
	
	in		al,			VIA1_T1C_L	; read T1C_L to clear VIA interrupt
	mov		al,			0x20		; EOI byte for OCW2 (always 0x20) - clear PIC interrupt
	out		PICM_P0,	al			; to port for OCW2
	pop		ax
	ds0000out
	iret

isr_int_11h:			; BIOS Equipment Determination
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

	;push	ax
	;mov		al,	0x11
	;call	print_char_hex_spi
	;mov		al, ':'
	;call	print_char_spi
	;pop		ax
	;call	debug_print_interrupt_info_sm
	;call	print_char_newline_spi

	push	ds
	call	to0000ds

	;mov	ax,	0b00000000_00100000		;0x0002
	mov		ax, [equipment_list]

	pop		ds

	;push	ax
	;mov		al, ' '
	;call	print_char_spi
	;mov		al, ' '
	;call	print_char_spi
	;mov		al, ' '
	;call	print_char_spi
	;pop		ax
	;call	debug_print_interrupt_info_sm
	;call	print_char_newline_spi
	iret
	
isr_int_12h:			; Memory Size Determination
	;push	ax
	;mov		al,	0x12
	;call	print_char_hex_spi
	;mov		al, ':'
	;call	print_char_spi
	;pop		ax
	;call	debug_print_interrupt_info_sm
	;call	print_char_newline_spi

	push	ds
	call	to0000ds
	mov		ax,		[memory_size]		; number of contiguous 1k memory blocks found at startup
	pop		ds

	;push	ax
	;mov		al, ' '
	;call	print_char_spi
	;mov		al, ' '
	;call	print_char_spi
	;mov		al, ' '
	;pop		ax
	;call	print_char_spi
	;call	debug_print_interrupt_info_sm
	;call	print_char_newline_spi
	iret

isr_int_19h:			; bootstrap loader
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

isr_int_1ah:			; Real-time Clock
	; https://www.sparkfun.com/datasheets/BreakoutBoards/DS3234.pdf
	push	bp
	mov		bp,		sp
	ds0000

	;debug
	;push	ax
	;mov		al,	0x1a
	;call	print_char_hex_spi
	;mov		al, ':'
	;call	print_char_spi
	;pop		ax
	;call	debug_print_interrupt_info_sm
	;call	print_char_newline_spi


	.read_counter:					; 0x00
		cmp	ah, 0x00
		jne .set_counter

		;on return:
		;	AL = midnight flag, 1 if 24 hours passed since reset
		;	CX = high order word of tick count
		;	DX = low order word of tick count
		;incremented approximately 18.206 times per second
		;at midnight CX:DX is zero

		mov		al, 0
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

		; addr 0x82 = hours
		; addr 0x81 = minutes
		; addr 0x80 = seconds

		push	ax

		; ** HOURS **
		mov		ah,			0x82
		mov		al,			ch
		call	spi_write_RTC

		; ** MINUTES **
		mov		ah,			0x81
		mov		al,			cl
		call	spi_write_RTC

		; ** SECONDS **
		mov		ah,			0x80
		mov		al,			dh
		call	spi_write_RTC

		pop		ax
		jmp		.out
	.read_date:						; 0x04
		cmp		ah, 0x04
		jne		.set_date
		;on return:
		;	CH = century in BCD (decimal 19-23)
		;	CL = year in BCD
		;	DH = month in BCD
		;	DL = day in BCD
		;	CF = 0 if successful, 1 if error or clock not operating

		push	ax

		; ** MONTH, DAY **
		mov		al,			0x05
		call	spi_read_RTC
		and		al,			0b00011111
		mov		dh,			al
		;mov		al,			dh
		;;call	print_char_hex
		mov		al,			'/'
		;;call	print_char
		mov		al,			0x04
		call	spi_read_RTC
		and		al,			0b00111111
		mov		dl,			al
		;;call	print_char_hex
		mov		al,			'/'
		;;call	print_char


		; ** CENTURY, YEAR **
		; mov		al,			0x05
		; call	spi_read_RTC
		mov		ch,			0b00100000		; bcd 20 (not worried about 19 or 21)
		mov		al,			0x06
		call	spi_read_RTC
		mov		cl,			al
		;;call	print_char_hex

		pop		ax
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
		
		push	ax

		; ** CENTURY, MONTH **
		mov		ah,			0x85
		mov		al,			0b10000000		; bcd 20
		or		al,			dh
		call	spi_write_RTC

		; ** YEAR **
		mov		ah,			0x86
		mov		al,			cl
		call	spi_write_RTC

		; ** DAY **
		mov		ah,			0x84
		mov		al,			dl
		call	spi_write_RTC

		pop		ax	
		jmp		.out
	.unimplemented:
		mov		al, 0x1a
		call	missing_interrupt_tospi
	.out:
		
		; **** debug int out **********
		;pushf	;push flags, just in case anything in .out modified flags
		;push	ax
		;push	es
		;push	0x00
		;pop		es
		;lahf
		;mov		es:[flags_debug],	ah
		;pop		es
		;pop		ax
		;push	ax
		;mov		al, ' '
		;call	print_char_spi
		;mov		al, ' '
		;call	print_char_spi
		;mov		al, ' '
		;call	print_char_spi
		;call	debug_print_interrupt_info_sm
		;call	print_char_newline_spi
		;pop		ax
		;popf
		; *** /debug int out **********

		ds0000out

		; *****************************
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

via_timer_init:
	push	ax

	mov		ax,				VIA1_TIMER
	out		VIA1_T1C_L,		al
	xchg	ah,				al
	out		VIA1_T1C_H,		al

	mov		al,				0b01000000		; continuous interrupts (T1); disable T2, shift register, and latch
	out		VIA1_ACR,		al
	mov		al,				0b11000000		; enable timer 1
	out		VIA1_IER,		al

	pop		ax
	ret