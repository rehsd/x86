process_os_command:
	push	bx

	add		word	[cursor_pos_v],		9
	mov		word	[cursor_pos_h],		0
	
	mov		bx,	os_buffer
	call	get_length					; bx => string to get length, result in dx
	mov		cx,		dx
	mov		si,		os_buffer
	
	.test_cmd_ver:
		mov		di,					os_cmd_ver
		call	strings_equal
		cmp		ax,					0x01
		jne		.test_cmd_help			; next test
		call	cmd_ver
		jmp		.out

	.test_cmd_help:
		mov		di,					os_cmd_help
		call	strings_equal
		cmp		ax,					0x01
		jne		.test_cmd_cls			; next test
		call	cmd_help
		jmp		.out
		
	.test_cmd_cls:
		mov		di,					os_cmd_cls
		call	strings_equal
		cmp		ax,					0x01
		jne		.test_cmd_rundoscomc				; next test
		call	cmd_cls
		jmp		.out

	.test_cmd_rundoscomc:
		mov		di,					os_cmd_rundoscomc
		call	strings_equal
		cmp		ax,					0x01
		jne		.test_cmd_rundoscomcpp			; next test
		call	cmd_rundoscomc
		jmp		.out

	.test_cmd_rundoscomcpp:
		mov		di,					os_cmd_rundoscommandcom
		call	strings_equal
		cmp		ax,					0x01
		jne		.test_cmd_command_com			; next test
		call	cmd_rundoscomcpp
		jmp		.out

	.test_cmd_command_com:
		mov		di,					os_cmd_rundoscomcpp
		call	strings_equal
		cmp		ax,					0x01
		jne		.test_cmd_update_bios			; next test
		call	cmd_command_com
		jmp		.out

	.test_cmd_update_bios:
		mov		di,					os_cmd_update_bios
		call	strings_equal
		cmp		ax,					0x01
		jne		.test_cmd_reboot				; next test
		call	cmd_update_bios
		jmp		.out

	.test_cmd_reboot:
		mov		di,					os_cmd_reboot
		call	strings_equal
		cmp		ax,					0x01
		jne		.nomatch			; next test
		call	reboot
		jmp		.out

	.nomatch:
		push	word [vga_param_color]
		mov		word [vga_param_color],		0b11111_000000_00000		; red
		mov		bx,		os_cmd_unrecognized
		call	print_message_vga
		pop		word [vga_param_color]
	.out:
		;call	print_RAMmessage_vga
		call	clear_os_buffer
		pop		bx
		ret

cmd_help:
	push	word [vga_param_color]
	mov		word [vga_param_color],		0b11000_110000_11111
	push	bx
	mov		bx,		msg_cmd_help1
	call	print_message_vga
	
	add		word	[cursor_pos_v],		9		; next line
	mov		word	[cursor_pos_h],		0

	mov		word [vga_param_color],		0b00000_110000_11100
	mov		bx,		msg_cmd_help2
	call	print_message_vga	

	add		word	[cursor_pos_v],		9		; next line
	mov		word	[cursor_pos_h],		0

	mov		bx,		msg_cmd_help3
	call	print_message_vga	
	pop		bx
	pop		word [vga_param_color]
	ret
	
cmd_ver:
	push	word [vga_param_color]
	mov		word [vga_param_color],		0b11111_111111_00000		; yellow
	push	bx
	mov		bx,		msg_vga_post_version
	call	print_message_vga
	pop		bx
	pop		word [vga_param_color]
	ret

cmd_cls:
	push	dx
	call	lcd_clear
	call	vga_swap_frame
	mov		dx,		0x0000			; black screen
	call	vga_init
	pop		dx
	ret

copy_com_c:
	; load .com into RAM
	push	ds
	push	si
	push	es
	push	di
	push	cx

	;		DS:SI -> source data
	;		ES:DI -> target buffer
	;		CX     = Number of words to copy

	push	0xe000			; dos com is at 0xe0100 in flash bios (for now - testing)
	pop		ds
	mov		si, 0x0000
	push	0x2000			; copy to 0x20000 in RAM
	pop		es
	mov		di, 0x0
	mov		cx, 16384		;  #words to copy -  copy the full 64k segment	(the dos com must fit in a 64k segment)
	call	memcpy_w

	pop		cx
	pop		di
	pop		es
	pop		si
	pop		ds
	ret

copy_com_cpp:
	; load .com into RAM
	push	ds
	push	si
	push	es
	push	di
	push	cx

	;		DS:SI -> source data
	;		ES:DI -> target buffer
	;		CX     = Number of words to copy

	push	0xe000			; dos com is at 0xe0100 in flash bios (for now - testing)
	pop		ds
	mov		si, 0x8000		
	push	0x2000			; copy to 0x20000 in RAM
	pop		es
	mov		di, 0x0
	mov		cx, 16384		;  #words to copy - temp-only copying 32k --copy the full 64k segment	(the dos com must fit in a 64k segment)
	call	memcpy_w

	pop		cx
	pop		di
	pop		es
	pop		si
	pop		ds
	ret

cmd_rundoscomc:
	call	copy_com_c
	call	lcd_clear
	; CS=DS=ES=SS, IP=100, SP=max size of block.
	mov		ax,		0x2000
	mov		ds,		ax
	mov		es,		ax
	mov		ss,		ax
	mov		ax,		0xfffe		; could be 0x0
	mov		sp,		ax
	; cs, ip will change with following jmp
	jmp 0x2000:0x0100			; Jump to embedded DOS .com at 0x20100
	ret

cmd_rundoscomcpp:
	call	copy_com_cpp
	call	lcd_clear
	; CS=DS=ES=SS, IP=100, SP=max size of block.
	mov		ax,		0x2000
	mov		ds,		ax
	mov		es,		ax
	mov		ss,		ax
	mov		ax,		0xfffe		; could be 0x0
	mov		sp,		ax
	; cs, ip will change with following jmp
	jmp 0x2000:0x0100			; Jump to embedded DOS .com at 0x28100
	ret

cmd_command_com:
	call	copy_com_cpp
	call	lcd_clear
	; CS=DS=ES=SS, IP=100, SP=max size of block.
	mov		ax,		0x2000
	mov		ds,		ax
	mov		es,		ax
	mov		ss,		ax
	mov		ax,		0xfffe		; could be 0x0
	mov		sp,		ax
	; cs, ip will change with following jmp
	jmp 0x2000:0x0100			; Jump to embedded DOS .com at 0x28100
	ret

debug_print_word_hex:
	; print msb
	push	ax
	xchg	ah, al
	mov		ah, 0x02			; spi cmd 2 - print char hex
	call	spi_send_NanoSerialCmd
	pop		ax

	; print lsb
	push	ax
	mov		ah, 0x02			; spi cmd 2 - print char hex
	call	spi_send_NanoSerialCmd
	pop		ax

	ret

debug_print_function_info_hex:
	push	ax
	mov		ah, 0x02			; spi cmd 2 - print char hex
	call	spi_send_NanoSerialCmd
	pop		ax
	ret

debug_print_function_info_char:
	push	ax
	mov		ah, 0x01			; spi cmd 2 - print char hex
	call	spi_send_NanoSerialCmd
	pop		ax
	ret

debug_print_newline:
	push	ax

	mov		ah, 0x01			; spi cmd 1 - print char
	mov		al, 0x0a			; newline char
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop
	
	pop		ax
	ret

debug_print_interrupt_info:
	push	ax		; save ax

	xchg	ah, al
	mov		ah, CMD_PRINT_INTERRUPT>>8
	call	spi_send_NanoSerialCmd
	call	delay

	;call	debug_print_newline
	
	mov		ah, 0x01			; spi cmd 1 - print char
	mov		al, 0x09			; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	pop		ax		; retrieve ax
	push	ax		; save ax again

	call	debug_print_word_hex		; print ax
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, bx
	call	debug_print_word_hex		; print bx
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, cx
	call	debug_print_word_hex		; print cx
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, dx
	call	debug_print_word_hex		; print dx
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, cs
	call	debug_print_word_hex		; print cs
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, ds
	call	debug_print_word_hex		; print ds
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, es
	call	debug_print_word_hex		; print es
	nop
	nop
	nop
	nop

	;call	debug_print_newline
	mov		ah, 0x01			; spi cmd 1 - print char
	mov		al, 0x09			; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	pop		ax
	ret

debug_print_interrupt_info_sm:
	push	ax		; save ax

	pop		ax		; retrieve ax
	push	ax		; save ax again

	call	debug_print_word_hex		; print ax
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, bx
	call	debug_print_word_hex		; print bx
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, cx
	call	debug_print_word_hex		; print cx
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, dx
	call	debug_print_word_hex		; print dx
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, cs
	call	debug_print_word_hex		; print cs
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, ds
	call	debug_print_word_hex		; print ds
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, es
	call	debug_print_word_hex		; print es
	nop
	nop
	nop
	nop

	;call	debug_print_newline
	mov		ah, 0x01			; spi cmd 1 - print char
	mov		al, 0x09			; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	pop		ax
	ret

to0000ds:
	push	0x0000
	pop		ds
	ret

to2000ds:
	push	0x2000
	pop		ds
	ret

dos_services_isr:		; interrupt 0x21
	; to do: switch logic to jump table
	; ah = function

	;push	ds
	push	es

	call	debug_print_interrupt_info

	push	ax
	mov		ax,		0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0c30000). 
	mov		es,		ax
	pop		ax

	.dos_terminate:		; 0x00
		cmp		ah,		0x00	
		jne		.gettime
		mov		ax, 't'
		;call	print_char
		call	debug_print_function_info_char
		nop
		nop
		nop
		nop
		jmp		.out
	.gettime:			; 0x2c
		cmp		ah,		0x2c
		jne		.dos_ver
		; CH = hour (0-23)
		; CL = minutes (0-59)
		; DH = seconds (0-59)
		; DL = hundredths (0-99)

		; SPI call to RTC
		; Current RTS does NOT support milliseconds, so always returning 0 for milliseconds,
		;									resulting in smallest time change of 1 second

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
		
		; ** MILLISECONDS **
		; not yet supported on hardware
		mov		dl,			0x00

		call	to2000ds

		jmp		.out
	.dos_ver:			; 0x30
		cmp		ah,		0x30			; ah/al swapped earlier
		jne		.openfile
		mov		ax, 'v'
		call	debug_print_function_info_char
		nop
		nop
		nop
		nop
		mov		al, 5		; major version
		mov		ah, 0		; minor version
		jmp		.out
	.openfile:			; 0x3d
		cmp		ah,		0x3d
		jne		.closefile
		mov		ax, 'f'
		;call	print_char
		call	debug_print_function_info_char
		mov		ax,		0x01	; file handle
		jmp		.out
	.closefile:			; 0x3e
		cmp		ah,		0x3e
		jne		.read
		mov		ax, 'c'
		;call	print_char
		call	debug_print_function_info_char
		jmp		.out
	.read:				; 0x3f
		cmp		ah,		0x3f
		jne		.write

		;BX = file handle
		;CX = number of bytes to read
		;DS:DX = pointer to read buffer
		;return: 	AX = number of bytes read
		push	dx		;*****

		mov		ax, 'r'
		call	debug_print_function_info_char

		call	to0000ds

		call	clear_os_buffer

		; set release flag, since it didn't get set when switching over ISR from original to DOS COM kbd ISR
		mov		al,					[kb_flags]
		or		al,					RELEASE
		;mov		[kb_flags],			al
		; clear bit to track if line is ready
		;mov		al,					[kb_flags]
		and		al,					~KBD_DOS_LINE_READY
		mov		[kb_flags],			al

		;change keyboard ISR
		mov word [KBD_IVT_OFFSET],				kbd_isr_doscom		
		mov word [KBD_IVT_OFFSET+2],			0xC000		
		
		;let the PIC know we're done with interrupt
		mov		al,			0x20		; EOI byte for OCW2 (always 0x20)
		out		PICM_P0,	al			; to port for OCW2
		nop
		nop
		sti		; allow interrupts
		nop
		nop

		;wait for line, ending in return
		.wait_loop:
			mov		al,		[kb_flags]
			test	al,		KBD_DOS_LINE_READY
			jz		.wait_loop

			mov		ax, '|'
			call	debug_print_function_info_char


		cli		; disable interrupts


		mov		bx,	os_buffer				
		call	get_length					; bx => string to get length, result in dx
		mov		cx,		dx					; place length into cx to support loop below

		mov		di,		0					; index to use with OS string buffer
		
		pop		bx	; put original dx pointer into bx

		mov		ax, cx
		call	print_char_hex		;***********

		.char_loop:
			mov		al,		ds:os_buffer+di
			call	debug_print_function_info_char		;************************ temp ******************
			
			call	to2000ds
			mov		byte ds:[bx],	al	
			call	to0000ds

			inc		di
			inc		bx
			loop	.char_loop
		
		; terminate with newline char \n 0x0a
		call	to2000ds
		mov		byte ds:[bx],	0x0a		;newline terminator
		inc		dx
		mov		ax,		dx					; return length of what was written
		
		;revert keyboard ISR
		call	to0000ds
		mov word [KBD_IVT_OFFSET],				kbd_isr		
		mov word [KBD_IVT_OFFSET+2],			0xC000
		call	to2000ds
		jmp		.out
	.write:				; 0x40
		cmp		ah,		0x40
		jne		.movefilepointer

		mov		ax, 'w'
		call	debug_print_function_info_char
		mov		ax, '['
		call	debug_print_function_info_char
		mov		ax, '0'
		call	debug_print_function_info_char
		mov		ax, 'x'
		call	debug_print_function_info_char
		mov		ax, cx
		call	debug_print_function_info_hex
		mov		ax, ']'
		call	debug_print_function_info_char
		mov		ax, ':'
		call	debug_print_function_info_char

		;BX = file handle
		;CX = number of bytes to write
		;DS:DX = pointer to write buffer			; where the string is

		push	ds
		push	dx
		push	cx

		;repeat for # bytes in cx
		.chars:
			mov		bx,	dx
			mov		ax, ds:[bx]
			call	debug_print_function_info_char
			
			push	ds
			
			push	0
			pop		ds
			mov		ah, 0x0a
			int		0x10		; video bios interrupt (ah=0a for printchar, al=char)
			
			pop		ds
			inc		dx
			loop	.chars
		
		pop		cx
		pop		dx
		pop		ds

		push	0x2000
		pop		ds

		mov		ax,	cx		; bytes written
		jmp		.out
	.movefilepointer:
		cmp		ah,		0x42
		jne		.ioctl
		mov		ax, 'm'
		;call	print_char
		call	debug_print_function_info_char
		jmp		.out
	.ioctl:				; 0x44
		cmp		ah,		0x44
		jne		.setblock
		mov		ax, 'i'
		call	debug_print_function_info_char
		; 4400 = get device info
		mov		dx,		0b00000000_10000010			;char dev, stdout
		jmp		.out	
	.setblock:				; modify allocated memory blocks
		cmp		ah,		0x4a
		jne		.terminateprocess
		mov		ax, 'b'
		call	debug_print_function_info_char
		jmp		.out
	.terminateprocess:
		cmp		ah,		0x4c
		jne		.getleadbytetable
		mov		ax, 'z'
		call	debug_print_function_info_char
		
		;*** SETUP REGISTERS ********************************** copied from initial boot sequence
		xor		ax,	ax
		mov		ds, ax
		mov		sp,	ax				; Start stack pointer at 0. It will wrap around (down) to FFFE.
		mov		ax,	0x0040			; First 1K is reserved for interrupt vector table,
		mov		ss,	ax				; Start stack segment at the end of the IVT.
		mov		ax, 0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0x30000). 
									; Move es to this by default to easy access to constants.
		mov		es,	ax				; extra segment
		;*** /SETUP REGISTERS *********************************

		call	debug_print_newline
		call	debug_print_newline

		jmp 0xc000:resume

		;jmp		.out
	.getleadbytetable:
		cmp		ah,		0x63
		jne		.globalcodepage
		mov		ax, 'l'
		call	debug_print_function_info_char
		; return values...
		mov		al,	0x00
		jmp		.out
	.globalcodepage:
		cmp		ah,		0x66
		jne		.flushbuffer
		;mov		ax, 'g'
		call	debug_print_function_info_char
		call	print_char
		; 6601 = get global code page
		jmp		.out
	.flushbuffer:
		cmp		ah,		0x68
		jne		.unimplemented
		mov		ax, 'f'
		call	debug_print_function_info_char
		push	0x2000
		pop		ds
		jmp		.out
	.unimplemented:
		mov		al, '!'
		call	print_char
		call	debug_print_function_info_char

		call	play_error_sound
		call	delay
		call	play_error_sound
		call	delay
		call	play_error_sound
		hlt		; temporary
	.out:
		push	ax
		mov		ax, ' '
		call	debug_print_function_info_char
		pop		ax
		
		pop		es
		;pop		ds

		push	0x2000
		pop		es


		call	debug_print_interrupt_info_sm
		call	debug_print_newline

		iret