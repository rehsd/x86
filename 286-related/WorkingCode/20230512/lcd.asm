;print_message_old:
	;mov		al,		'R'
	;call	print_char
	;mov		al,		'e'
	;call	print_char
	;mov		al,		'a'
	;call	print_char
	;mov		al,		'd'
	;call	print_char
	;mov		al,		'y'
	;call	print_char
;	mov		al,		'>'
;	call	print_char
;	ret

print_message_lcd:
	; Send a NUL-terminated string to the LCD display;
	; In: DS:BX -> string to print
	; Return: AX = number of characters printed
	; All other registers preserved or unaffected.
	; **thank you, Damouze!

	push	bx 					; Save BX 
	push	cx 					; and CX onto the sack
	mov		cx, bx 				; Save contents of BX for later use
	
	.loop:
		mov		al, es:[bx]		; Read byte from [DS:BX]
		or		al, al 			; Did we encounter a NUL character?
		jz		.return 		; If so, return to the caller
		call	print_char 		; call our character print routine
		inc		bx 				; Increment the index
		jmp		.loop 			; And loop back
	
	.return: 
		sub		bx, cx 			; Calculate our number of characters printed
		mov		ax, bx 			; And load the result into AX
		pop		cx 				; Restore CX
		pop		bx 				; and BX from the stack
		ret 					; Return to our caller

print_char:
	call	lcd_wait
	push	dx
	push	ax

	mov		dx,		PPI1_PORTA			; Get A port address
	out		dx,		al					; Write data (e.g. char) to port A
	mov		al,		(RS | E)			; RS=1, RW=0, E=1
	mov		dx,		PPI1_PORTB			; Get B port address
	out		dx,		al					; Write to port B - enable high
	nop									; wait for high-to-low pulse to be wide enough
	nop
	mov		al,		RS					; RS=1, RW=0, E=0
	out		dx,		al					; Write to port B - enable low

	pop		ax
	pop		dx
	ret

print_char_hex:
	push	ax

	; mov		al,		'x'
	; call	print_char
	; pop		ax
	; push	ax
	
	and		al,		0xf0		; upper nibble of lower byte
	shr		al,		4
	cmp		al,		0x0a
	sbb		al,		0x69
	das
	call	print_char

	pop		ax
	push	ax
	and		al,		0x0f		; lower nibble of lower byte
	cmp		al,		0x0a
	sbb		al,		0x69
	das
	call	print_char

	pop		ax
	ret

print_hex_byte:
	; Print the byte in AL as hex digits to the screen
	; In:	AL = byte to print
	; Return: Nothing
	; thank you, @Damouze
    
	rol     al, 4
    call    nibble_to_hex
    call    print_char
    rol     al, 4 
    call    print_char
    ret

print_char_dec:
	; al contains the binary value that will be converted to ascii and printed to the 2-line LCD
	push	ds
	push	ax
	push	bx
	call	to0000ds

	mov	[dec_num],				al
	mov	byte [dec_num100s],		0
	mov	byte [dec_num10s],		0
	mov	byte [dec_num1s],		0

	.hundreds_loop:
		mov	al,			[dec_num]
		cmp	al,			100				; compare to 100
		jb				.tens_loop
		mov	al,			[dec_num]
		stc								; set carry
		sbb	al,			100				; subtract 100
		mov	[dec_num],	al
		inc	byte [dec_num100s]
		jmp .hundreds_loop

	.tens_loop:
		mov	al,			[dec_num]
		cmp	al,			10				; compare to 10
		jb				.ones_loop
		mov	al,			[dec_num]
		stc								; set carry
		sub	al,			10				; subtract 10
		mov	[dec_num],	al
		inc	byte [dec_num10s]
		jmp .tens_loop
		
	.ones_loop:
		mov	al,				[dec_num]
		mov [dec_num1s],	al

	;mov	si,		[dec_num100s]						; should this work??
	;mov	al,		byte ES:[hexOutLookup,si]			;
	;call		print_char_hex

	mov		al,		[dec_num100s]
	cmp		al,		0
	je		.print_10s
	call	print_char_dec_digit
	.print_10s:
	mov		al,		[dec_num10s]
	call	print_char_dec_digit
	mov		al,		[dec_num1s]
	call	print_char_dec_digit

	pop		bx
	pop		ax
	pop		ds
	ret

print_char_dec_digit:
	push	ds
	push	ax
	call	to0000ds
	cmp		al,		0x0a
	sbb		al,		0x69
	das
	call	print_char
	pop		ax
	pop		ds
	ret

lcd_wait:
	push	ax				
	push	dx
	mov		al,					CTL_CFG_PA_IN		; Get config value
	mov		dx,					PPI1_CTL			; Get control port address
	out		dx,					al					; Write control register on PPI
	;mov		[ppi1_ccfg],		al					; Remember current config
	.again:	
		mov		al,				(RW)				; RS=0, RW=1, E=0
		mov		dx,				PPI1_PORTB			; Get B port address
		out		dx,				al					; Write to port B
		mov		al,				(RW|E)				; RS=0, RW=1, E=1
		out		dx,				al					; Write to port B
	
		mov		dx,				PPI1_PORTA			; Get A port address

		in		al,				dx				; Read data from LCD (busy flag on D7)
		rol		al,				1				; Rotate busy flag to carry flag
		jc		.again							; If CF=1, LCD is busy
		mov		al,				CTL_CFG_PA_OUT	; Get config value
		mov		dx,				PPI1_CTL		; Get control port address
		out		dx,				al				; Write control register on PPI
		;mov		[ppi1_ccfg],	al					; Remember current config

	pop	dx
	pop	ax
	ret

lcd_clear:
	push	ax
    mov		al,		0b00000001		; Clear display
	call	lcd_command_write
	nop
	pop		ax
	ret

lcd_line2:
	push	ax
	mov		al,		0b10101000		; Go to line 2
	call	lcd_command_write
	pop		ax
	ret

lcd_init:
	push	ax
	mov		al,		0b00111000	;0x38	; Set to 8-bit mode, 2 lines, 5x7 font
	call	lcd_command_write
	mov		al,		0b00001110	;0x0E	; LCD on, cursor on, blink off
	call	lcd_command_write
	mov		al,		0b00000001	;0x01	; clear LCD
	call	lcd_command_write
	mov		al,		0b00000110  ;0x06	; increment and shift cursor, don't shift display
	call	lcd_command_write
	pop		ax
	ret

lcd_command_write:
	call	lcd_wait
	push	dx
	push	ax
	mov		dx,		PPI1_PORTA			; Get A port address
	out		dx,		al					; Send al to port A
	mov		dx,		PPI1_PORTB			; Get B port address
	mov		al,		E					; RS=0, RW=0, E=1
	out		dx,		al					; Write to port B
	nop									; wait for high-to-low pulse to be wide enough
	nop
	mov		al,		0x0					; RS=0, RW=0, E=0
	out		dx,		al					; Write to port B

	pop		ax
	pop		dx
	ret
