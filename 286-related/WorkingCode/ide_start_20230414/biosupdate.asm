download_BIOS_to_Nano:
	mov		ax,	CMD_GET_BIOS					; download BIOS from PC to Nano (no parameter to this command)
	call	spi_send_NanoSerialCmd
	call	delay
	ret

display_Cached_BIOS:
	mov		ax, CMD_DISPLAY_CACHED_BIOS			; Display portions of cached BIOS for manual validation (Nano serial output)
	call	spi_send_NanoSerialCmd
	call	delay
	ret

shadow_start:
	;ROM is moved into RAM, starting at 0x6000:0000

	;*** SETUP REGISTERS ******** SHADOW ******************
	;mov		ax, 0x6000
	;mov		ds, ax				; Data segment is now at 0x6000
	;mov		ax,	0xa000
	;mov		sp,	ax				; Start stack pointer at a000. It will wrap around (down) to 9FFE.
	;mov		ax,	0x6040			; First 1K is reserved for interrupt vector table,
	;mov		ss,	ax				; Start stack segment at the end of the IVT.
	mov		ax, 0x9000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0x30000). 
								; Move es to this by default to easy access to constants.
	mov		es,	ax				; extra segment
	;*** /SETUP REGISTERS *********************************

	call	cmd_update_bios_cont
		
	call	lcd_clear
	mov		ax,	'1'
	call	print_char
	mov		ax,	'0'
	call	print_char
	mov		ax,	'0'
	call	print_char
	mov		ax,	'%'
	call	print_char
	mov		ax,	'!'
	call	print_char
	call	lcd_line2
	mov		ax,	'R'
	call	print_char
	mov		ax,	'e'
	call	print_char
	mov		ax,	's'
	call	print_char
	mov		ax,	'e'
	call	print_char
	mov		ax,	't'
	call	print_char
	mov		ax,	't'
	call	print_char
	mov		ax,	'i'
	call	print_char
	mov		ax,	'n'
	call	print_char
	mov		ax,	'g'
	call	print_char
	mov		ax,	'.'
	call	print_char
	mov		ax,	'.'
	call	print_char
	mov		ax,	'.'
	call	print_char

	call	reboot

copy_rom_to_ram:
	push	ds
	push	si
	push	es
	push	di
	push	cx

	;		DS:SI -> source data
	;		ES:DI -> target buffer
	;		CX     = Number of words to copy
	
	; to do - loop

	; c00000
	push	0xc000
	pop		ds
	mov		si, 0x0
	push	0x6000
	pop		es
	mov		di, 0x0
	mov		cx, 32768		; copy the full 64k segment
	call	memcpy_w

	; d00000
	push	0xd000
	pop		ds
	mov		si, 0x0
	push	0x7000
	pop		es
	mov		di, 0x0
	mov		cx, 32768		; copy the full 64k segment
	call	memcpy_w

	; e00000
	push	0xe000
	pop		ds
	mov		si, 0x0
	push	0x8000
	pop		es
	mov		di, 0x0
	mov		cx, 32768		; copy the full 64k segment
	call	memcpy_w

	; f00000
	push	0xf000
	pop		ds
	mov		si, 0x0
	push	0x9000
	pop		es
	mov		di, 0x0
	mov		cx, 32768		; copy the full 64k segment
	call	memcpy_w

	pop		cx
	pop		di
	pop		es
	pop		si
	pop		ds
	ret

test_flash_write:
	push	ax
	push	bx
	push	cx
	push	dx

	cli									; disable interrupts

	mov		al,		's'
	call	print_char

	mov		cx, 0xc000					; write to c0000 + offset in bx
	mov		bx, 0x0000					; offset within segment
	mov		dx,	0x0123					; data
	call	flash_write_word

	mov		cx, 0xc000					; write to c0000 + offset in bx
	mov		bx, 0x0002					; offset within segment
	mov		dx,	0x4567					; data
	call	flash_write_word

	mov		cx, 0xc000					; write to c0000 + offset in bx
	mov		bx, 0x0004					; offset within segment
	mov		dx,	0x89ab					; data
	call	flash_write_word

	mov		cx, 0xc000					; write to c0000 + offset in bx
	mov		bx, 0x0006					; offset within segment
	mov		dx,	0xcdef					; data
	call	flash_write_word


	mov		cx, 0xd000					; write to d0000 + offset in bx
	mov		bx, 0x0002					; offset within segment
	mov		dx,	0x4567					; data
	call	flash_write_word

	mov		cx, 0xe000					; write to e0000 + offset in bx
	mov		bx, 0x0004					; offset within segment
	mov		dx,	0x89ab					; data
	call	flash_write_word

	mov		cx, 0xf000					; write to f0000 + offset in bx
	mov		bx, 0x0006					; offset within segment
	mov		dx,	0xcdef					; data
	call	flash_write_word

	mov		al,		'c'
	call	print_char
	
	sti									; enable interrupts

	pop		dx
	pop		cx
	pop		bx
	pop		ax
	ret

flash_erase:
	push	ax
	push	bx
	push	cx
	push	dx

	cli									; disable interrupts

	;mov		al,		's'
	;call	print_char

	push	0xc000		; start of flash ROM
	pop		es
	
	mov		word es:[0xaaaa],	0xaaaa		; write 0xaa to 0x5555		byte-program software protection		; hi/lo flash roms - shift address left a bit, as flash ROMs have addresses shifted to the right (line a1 connects to pin a0) - send 0xaa to both
	mov		word es:[0x5554],	0x5555		; write 0x55 to 0x2aaa		byte-program software protection
	mov		word es:[0xaaaa],	0x8080		; write 0x80 to 0x5555		byte-program software protection
	mov		word es:[0xaaaa],	0xaaaa		; write 0xaa to 0x5555		byte-program software protection
	mov		word es:[0x5554],	0x5555		; write 0x55 to 0x2aaa		byte-program software protection
	mov		word es:[0xaaaa],	0x1010		; write 0x10 to 0x5555		byte-program software protection

	call	delay
	call	delay
	call	delay

	;mov		al,		'c'
	;call	print_char
	
	;sti									; enable interrupts

	pop		dx
	pop		cx
	pop		bx
	pop		ax
	ret

flash_write_word:
	; address in cx:bx
	; data to write in dx

	push	ax
	push	bx
	push	cx
	push	dx
	push	es

	push	0xc000		; start of flash ROM
	pop		es
	
	mov		word es:[0xaaaa],	0xaaaa		; write 0xaa to 0x5555		byte-program software protection		; hi/lo flash roms - shift address left a bit, as flash ROMs have addresses shifted to the right (line a1 connects to pin a0) - send 0xaa to both
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	mov		word es:[0x5554],	0x5555		; write 0x55 to 0x2aaa		byte-program software protection
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	mov		word es:[0xaaaa],	0xa0a0		; write 0xa0 to 0x5555		byte-program software protection
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	push	cx		; target of flash update
	pop		es

	mov		es:[bx],	dx			; write value to the location
	.loop:							; loop until update is complete
		mov		ax,			es:[bx]		
		cmp		ax,			dx
		nop
		nop
		jne		.loop
	
	nop
	nop
	nop
	nop
	nop

	pop		es
	pop		dx
	pop		cx
	pop		bx
	pop		ax
	ret

print_bios_percent_complete:
	push	ax
	
	call	lcd_clear
	mov		ax, di
	aam
	add		ax, 3030h
	xchg	al, ah
	
	cmp		al, 0x3a		; rolled past '9' to ':' --i.e., 100%
	je		.out
	
	call	print_char
	xchg	al, ah
	call	print_char
	mov		ax, '%'		
	call	print_char

	.out:
	pop		ax
	ret

cmd_update_bios_cont:
	
	mov		si, 0x0
	mov		di, 0x0
	call	lcd_clear


	call	flash_erase

	; *******************************************************
	mov		al,				( SPI_CS1 | SPI_CS2	| SPI_CS3 |			SPI_CS5 | SPI_MOSI)					; drop SPI_CS4 low to enable, start with MOSI high and CLK low
	mov		[spi_state_a],		al
	out		VIA1_PORTA,		al		
	nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
	;pop		ax						; get back original ax
	;push	ax						; save it again to stack

	mov		al,				CMD_DUE_GETBIOS
	call	spi_writebyte_port_a	; write high byte (i.e., SPI cmd)
	; *******************************************************

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		cx, 0xc000					; write to c0000 + offset in bx
	mov		bx, 0x0000					; offset within segment

	.loop:
		call	spi_readbyte_port_a
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		mov		dl,	al
		;call	print_char_hex


		call	spi_readbyte_port_a
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		mov		dh,	al
		;call	print_char_hex

		cmp		ax,		0xffff
		je		.skipwrite				; since the flash was erased and is all 0xffff's, don't write 0xffff's
		call	flash_write_word
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		.skipwrite:

		inc		si
		cmp		si, 1310
		jne		.cont
		inc		di
		call	print_bios_percent_complete
		mov		si, 0x0

		.cont:
			add		bx,		2
			jne		.loop				; rolled over, go to next segment
			add		cx,		0x1000
			jne		.loop				; segment rolled over == done
	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTA,		al	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	.out:

	call	play_sound

	;pop		bx
	;pop		ax
	;pop		word [vga_param_color]
	ret

cmd_update_bios:
	push	word [vga_param_color]
	mov		word [vga_param_color],		0b11111_111111_11111		; white
	;push	ax
	;push	bx
	mov		bx,		msg_update_bios
	call	print_message_vga
	call	play_sound

	;mov		ax, 's'
	;call	print_char
	
	call	copy_rom_to_ram
	
	;mov		ax, 'S'
	;call	print_char

	jmp 0x6000:shadow_start
