; Pre-Nano code, using onboard legacy circuit

kbd_isr:
	pusha
	
	mov		ax,					0x0000
	mov		ds,					ax

	;mov		ax, '$'
	;call	debug_print_function_info_char

	; if releasing a key, don't read PPI, but reset RELEASE flag
	mov		al,					[kb_flags]
	and		al,					RELEASE
	je		read_key								; if equal, releasing flag is not set, so continue reading the PPI
	mov		al,					[kb_flags]
	xor		al,					RELEASE				; clear the RELEASE flag
	mov		[kb_flags],			al

	call	kbd_get_scancode						; read scancode from PPI2 into al (for the key being released)
	cmp		al,						0x12			; left shift
	je		shift_up
	cmp		al,						0x59			; right shift
	je		shift_up
	jmp		kbd_isr_done

kbd_isr_done:
	mov		al,			0x20		; EOI byte for OCW2 (always 0x20)
	out		PICM_P0,	al			; to port for OCW2
	popa
	iret

kbd_isr_doscom:
	pusha

	mov		ax,					0x0000
	mov		ds,					ax
	
	;mov		ax, '@'
	;call	debug_print_function_info_char

	; if releasing a key, don't read PPI, but reset RELEASE flag
	mov		al,					[kb_flags]
	and		al,					RELEASE
	je		read_key_doscom							; if equal, releasing flag is not set, so continue reading the PPI
	mov		al,					[kb_flags]
	xor		al,					RELEASE				; clear the RELEASE flag
	mov		[kb_flags],			al

	call	kbd_get_scancode						; read scancode from PPI2 into al (for the key being released)
	cmp		al,						0x12			; left shift
	je		shift_up
	cmp		al,						0x59			; right shift
	je		shift_up
	jmp		kbd_isr_done

read_key:
	call	kbd_get_scancode		; read scancode from PPI2 into al
	;call	print_char_hex
	
	.filter:									; Filter out some noise scancodes
		;cmp		al,						0xaa		; ?		to do: identify - keyboard sends as part of first key on boot
		;je		key_release	
	.release:
		cmp		al,					0xf0		; key release
		je		key_release

	.shift:
		cmp		al,					0x12		; left shift
		je		shift_down
		cmp		al,					0x59		; right shift
		je		shift_down
	
	.esc:
		cmp		al,			0x76		; ESC
		jne		.enter
		
		call	lcd_clear
		mov		dx,		0x0000			; black screen
		call	vga_init
		jmp		key_release

	.enter:
		cmp		al,			0x5a		; ENTER
		jne		.f1
		call	enter_pressed
		jmp		key_release

	.f1:
		cmp		al,			0x05		; F1
		jne		.f2
		
		call	lcd_clear
		call	rtc_getTemp						; get temperature from RTC
		call	rtc_getTime						; get time from RTC
		call	lcd_line2

		jmp		key_release

	.f2:
		cmp		al,			0x06		; F2
		jne		.f3
		
		;call	lcd_clear
		;call	rtc_setTime						; get temperature from RTC
		;mov		al,	's'
		;call	print_char
		;mov		al,	'e'
		;call	print_char
		;mov		al,	't'
		;call	print_char
		;call	lcd_line2
		;call	rtc_getTime						; get time from RTC

		jmp		key_release

	.f3:
		cmp		al,			0x04		; F3
		jne		.f4
		;call	display_Cached_BIOS
		jmp		key_release
	.f4:
		cmp		al,			0x0c		; F4
		jne		.f5
		;		available -- do something here
		jmp		key_release
	.f5:		; black screen
		cmp		al,			0x03		; F5
		jne		.f6
		mov		dx,			0x0
		call	vga_init
		jmp		key_release
	.f6:		; white screen
		cmp		al,			0x0b		; F6
		jne		.f7
		mov		dx,			0xffff
		call	vga_init
		jmp		key_release
	.f7:		; test screen
		cmp		al,			0x83		; F7
		jne		.f8
		mov		dx,			0x0
		call	vga_init
		call	vga_draw_test_pattern
		jmp		key_release
	.f8:		; shapes
		cmp		al,			0x0a		; F8
		jne		.f9
		mov		dx,			0x0
		call	vga_init
		call	draw_shapes
		jmp		key_release
	.f9:		; image from sd card
		cmp		al,			0x01		; F9
		jne		.f11
		call	load_image_from_sdcard
		jmp		key_release
	.f11:		; update ROM
		cmp		al,			0x78
		jne		.f12
		;call	download_BIOS_to_Nano
		jmp		key_release

	.f12:
		cmp		al,			0x07		; F12
		jne		.ascii
		
		call	vga_swap_frame

		call	delay

		jmp		key_release


	; to do - check for other non-ascii
	; http://www.philipstorr.id.au/pcbook/book3/scancode.htm

	.ascii:
		call	kbd_scancode_to_ascii			; convert scancode to ascii
		push	di
		push	bx

		mov		bx,				0
		mov		bl,				[kb_wptr]
		mov		di,				bx
		mov		[kb_buffer+di],	al
		mov		di,				[os_buffer_wptr]
		mov		[os_buffer+di], al
		
		pop		bx
		pop		di
		call	keyboard_inc_wptr
		call	os_buffer_inc_wptr
		jmp		kbd_isr_done

read_key_doscom:
	mov		ax, 0x0000
	mov		ds, ax

	call	kbd_get_scancode		; read scancode from PPI2 into al
	;call	print_char_hex
	.release:
		cmp		al,					0xf0		; key release
		je		key_release

	.shift:
		cmp		al,					0x12		; left shift
		je		shift_down
		cmp		al,					0x59		; right shift
		je		shift_down
	
	.esc:
		cmp		al,			0x76		; ESC
		jne		.enter
		jmp		key_release

	.enter:
		cmp		al,			0x5a		; ENTER
		jne		.f1
		call	enter_pressed_doscom
		jmp		key_release

	.f1:
		cmp		al,			0x05		; F1
		jne		.f2
		jmp		key_release

	.f2:
		cmp		al,			0x06		; F2
		jne		.f3
		jmp		key_release

	.f3:
		cmp		al,			0x04		; F3
		jne		.f4
		jmp		key_release
	.f4:
		cmp		al,			0x0c		; F4
		jne		.f5
		jmp		key_release
	.f5:
		cmp		al,			0x03		; F5
		jne		.f6
		jmp		key_release
	.f6:
		cmp		al,			0x0b		; F6
		jne		.f7
		jmp		key_release
	.f7:
		cmp		al,			0x83		; F7
		jne		.f8
		jmp		key_release
	.f8:
		cmp		al,			0x0a		; F8
		jne		.f9
		jmp		key_release
	.f9:
		cmp		al,			0x01		; F9
		jne		.f11
		jmp		key_release
	.f11:
		cmp		al,			0x78
		jne		.f12
		jmp		key_release
	.f12:
		cmp		al,			0x07		; F12
		jne		.ascii
		jmp		key_release

	.ascii:
		call	kbd_scancode_to_ascii			; convert scancode to ascii
		
		mov		ah,			0x0a
		int		0x10		; video bios interrupt (ah=0a for printchar, al=char)
		
		push	di
		push	bx

		mov		bx,				0
		mov		bl,				[kb_wptr]
		mov		di,				bx
		mov		[kb_buffer+di],	al
		mov		di,				[os_buffer_wptr]
		mov		[os_buffer+di], al
		
		pop		bx
		pop		di
		call	keyboard_inc_wptr
		call	os_buffer_inc_wptr
		jmp		kbd_isr_done

shift_up:
	mov		al,					[kb_flags]
	xor		al,					SHIFT		; clear the shift flag
	mov		[kb_flags],			al
	jmp		kbd_isr_done

shift_down:
  	mov		al,					[kb_flags]
	or		al,					SHIFT		; set the shift flag
	mov		[kb_flags],			al
	jmp		kbd_isr_done

key_release:
	mov		al,					[kb_flags]
	or		al,					RELEASE		; set release flag
	mov		[kb_flags],			al
	jmp		kbd_isr_done

kbd_scancode_to_ascii:
	; ax is updated with the ascii value of the scancode originally in ax
	push	bx
	
	test	byte [kb_flags],		SHIFT
	jne		.shifted_key			; if shift is down, jump to .shifted_key, otherwise, process as not shifted key

	.not_shifted_key:
		;and		ax,		0x00FF		; needed?
		mov		bx,		ax
		mov		ax,		ES:[ keymap + bx]			; can indexing be done with bl? "invalid effective address"
		mov		ah,		0
		;and		ax,		0x00FF		; needed?
		jmp		.out

	.shifted_key:
		;and		ax,		0x00FF		; needed?
		mov		bx,		ax
		mov		ax,		ES:[ keymap_shifted + bx]			; can indexing be done with bl? "invalid effective address"
		mov		ah,		0
		;and		ax,		0x00FF		; needed?
		; fall into .out

	.out:
		pop		bx
		ret

; to do switch from original routine to this one
kbd_scancode_to_ascii_2:
	; In: AL = scancode
	; Return: AL= ASCII value
	; thank you, @Damouze

    call ToROM
    push bx
    mov bx, keymap
    xlatb
    pop bx
    call ToRAM
    ret

kbd_get_scancode:
	; Places scancode into al

	push	dx

	mov		al,				CTL_CFG_PB_IN
	mov		dx,				PPI2_CTL
	out		dx,				al
	mov		dx,				PPI2_PORTB			; Get B port address
	in		al,				dx					; Read PS/2 keyboard scancode into al
	mov		ah,				0					; testing - saftey

	pop		dx
	ret

key_pressed_done:
	call	keyboard_inc_rptr
	pop		ax
	jmp		main_loop

key_pressed:
	;called from main_loop: when the write and read pointers of the keyboard buffer don't match

	push	ax
	push	bx

	mov		bl,		[kb_rptr]
	mov		bh,		0
	mov		al,		[kb_buffer + bx]		; get the char from the keyboad buffer

	mov		word [print_char_options], 0b00000000_00000000		; restore default of frame swap
	
	mov		ah,		0x0a		; write character at current cursor position, no color specified
								; al=char to write
	int		0x10				; call interrupt 0x10
	;call	print_char_vga		; replaced with int call above
	
	call	keyboard_inc_rptr
	
	pop		bx
	pop		ax
	jmp		main_loop
