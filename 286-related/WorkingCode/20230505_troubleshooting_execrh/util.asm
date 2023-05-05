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
	; this version does not call CMD_PRINT_INTERRUPT on Nano

	push	ax

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
	mov		al, '_'						; horizontal tab
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
	call	debug_print_word_hex		; print cs
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, es
	call	debug_print_word_hex		; print ds
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '_'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, si
	call	debug_print_word_hex		; print cs
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	mov		ax, di
	call	debug_print_word_hex		; print cs
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '_'						; horizontal tab
	call	spi_send_NanoSerialCmd
	nop
	nop
	nop
	nop

	lahf
	push	es
	push	0x0
	pop		es
	mov		al,	es:[flags_debug]
	pop		es
	call	print_char_hex_spi
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

ToROM:
	push 	cs 					; push CS onto the stack	
	pop 	ds 					; and pop it into DS so that DS is in ROM address space
	ret

ToRAM:
	;push	ax
	;mov		ax,	0x0				; return DS back to 0x0
	;mov		ds, ax
	;pop		ax
	
	push		0x0
	pop			ds
	ret

delay:
	push	bp
	push	si

	mov		bp, 0xFFFF
	mov		si, 0x0001
	.delay2:
		dec		bp
		nop
		jnz		.delay2
		dec		si
		cmp		si,0    
		jnz		.delay2

	pop		si
	pop		bp
	ret

delay_configurable:
	; counter low word in bp
	; counter high word in si
	.loop:
		dec		bp
		nop
		jnz		.loop
		dec		si
		cmp		si,0    
		jnz		.loop
	ret

memcpy_b:
	; thank you, @Damouze!
	; memcpy(): copy data from DS:SI to ES:DI
	;
	; In:
	;		DS:SI -> source data
	;		ES:DI -> target buffer
	;		CX     = Number of bytes to copy
	; Return:
	;		All registers preserved
	;

	;
	; Preserve some registers first
	push	ds
	push	es
	push	si
	push	di
	push	cx

	rep		movsb

	.return:
		pop		cx
		pop		di
		pop		si
		pop		es
		pop		ds
		ret

memcpy_w:
	; thank you, @Damouze!
	; memcpy(): copy data from DS:SI to ES:DI
	;
	; In:
	;		DS:SI -> source data
	;		ES:DI -> target buffer
	;		CX     = Number of words to copy
	; Return:
	;		All registers preserved
	;

	;
	; Preserve some registers first
	push	ds
	push	es
	push	si
	push	di
	push	cx

	rep		movsw

	.return:
		pop		cx
		pop		di
		pop		si
		pop		es
		pop		ds
		ret

nibble_to_hex:
	; Convert nibble to ASCII hex character
	; In:           AL = nibble
	; Return:       AL = hex character ('0' through '9', 'A' through 'F')
	; thank you, @Damouze
    
	and     al, 0x0f
    add     al, 0x90
    daa
    adc     al, 0x40
    daa
    ret

print_string_to_serial:
	; Assuming string is in ROM .rodata section
	; Send a NUL-terminated string;
	; In: DS:BX -> string to print
	; Return: AX = number of characters printed
	; All other registers preserved or unaffected.

	push	bx 					; Save BX 
	push	cx 					; and CX onto the sack
	mov		cx, bx 				; Save contents of BX for later use
	
	.loop:
		mov		al, ES:[bx]		; Read byte from [DS:BX]
		or		al, al 			; Did we encounter a NUL character?
		jz		.return 		; If so, return to the caller
		mov		ah,		0x01	; spi cmd 1 - print char

		call	spi_send_NanoSerialCmd

		inc		bx 				; Increment the index
		jmp		.loop 			; And loop back
	
	.return: 
		sub		bx, cx 			; Calculate our number of characters printed
		mov		ax, bx 			; And load the result into AX
		pop		cx 				; Restore CX
		pop		bx 				; and BX from the stack
		ret 					; Return to our caller

get_length_w: 
	; in: bx => pointing to string where each char is represented by a word
	; out: dx = length

	push	ax
	push	bx

	mov		dx,	0
	dec		bx
	.loop:  
		inc     bx
		inc		dx
		mov		al,	[bx]
		inc		bx		; skip the high byte of word
        cmp     al, 0
        jne     .loop

	dec		dx
	dec		dx
	pop		bx
	pop		ax
	ret

get_length_w2: 
	; in: bx => pointing to string where each char is represented by a word
	; out: dx = length

	push	ax
	push	bx

	mov		dx,	0
	dec		bx
	.loop:  
		inc     bx
		inc		dx
		mov		al,	[bx]
		inc		bx		; skip the high byte of word
        cmp     al, 0
        jne     .loop

	dec		dx
	;dec		dx
	pop		bx
	pop		ax
	ret

strings_equal:
	;compare RAM string to ROM string
	;in ds:si = keyboard input string (in RAM)
	;in es:di = comparison string (lookup in ROM)
	;in cx = length of comparison
	;out ax = 1 when match, 0 when no match

	push	cx
	push	si
	mov		ax	,	0

	cld						;left to right or auto-increment mode 
	.loop:	
		cmpsb  				;compare until equal or cx=0
		jb	.out
		ja	.out
	;so far, matching
		inc	si				; the keyboard buffer is using a word per char, while the data in ROM to compare with is a byte, so skip the high byte of the buffer word
	loop .loop
	
	mov ax, 1	; all match, so set ax to 1
	.out:
		pop	si
		pop	cx
		ret

es_point_to_rom:
	push	ax
	
	;push	0xf000
	mov		ax, 0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0c30000). 
								; Move es to this by default to easy access to constants.
	
	;pop		es
	mov		es,	ax				; extra segment
	
	pop		ax
	ret
