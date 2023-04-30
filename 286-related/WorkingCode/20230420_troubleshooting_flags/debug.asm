; Beep codes
; 2 beeps ==> Missing Interrupt Service Routine (see LCD output for interrupt #)
; 4 beeps ==> INT21 OS Services \ unimplemented
; 5 beeps ==> INT13 Disk Services \ unimplemented
; 6 beeps ==> INT10 Video Services \ unimplemented

isr_int_15h:
	; take in test values on all registers, print, modify, return

	push	ax
	mov		al, '1'
	call	print_char_spi
	mov		al, '5'
	call	print_char_spi
	mov		al, ':'
	call	print_char_spi
	pop		ax
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi
	
	call	debug_print_word_hex		; print ax
	mov		ax, '-'
	call	print_char_spi

	mov		ax, bx
	call	debug_print_word_hex		; print bx
	mov		ax, '-'
	call	print_char_spi

	mov		ax, cx
	call	debug_print_word_hex		; print cx
	mov		ax, '-'
	call	print_char_spi

	mov		ax, dx
	call	debug_print_word_hex		; print dx
	mov		ax, ' '
	call	print_char_spi

	mov		ax, cs
	call	debug_print_word_hex		; print cs
	mov		ax, '-'
	call	print_char_spi

	mov		ax, ds
	call	debug_print_word_hex		; print ds
	mov		ax, '-'
	call	print_char_spi

	mov		ax, es
	call	debug_print_word_hex		; print es
	mov		ax, ' '
	call	print_char_spi

	mov		ax, di
	call	debug_print_word_hex		; print di
	mov		ax, '-'
	call	print_char_spi

	mov		ax, si
	call	debug_print_word_hex		; print si
	mov		ax, ' '
	call	print_char_spi

	lahf
	mov		al, ah
	call	print_char_hex_spi		; print flags

	call	print_char_newline_spi


	; *** test values to return ***
	mov		ah, 0b01000001				;SF, ZF, AF, PF, and CF flags (bits 7, 6, 4, 2, and 0, respectively)
	sahf
	pushf
	mov		ax, 0x1234
	mov		bx, 0x5678
	mov		cx, 0x9abc
	mov		dx, 0xdef0
	mov		di, 0x2468
	mov		si, 0x3579

	;pushf				;0			;push flags, just in case anything in .out modified flags
	push	ax			;1
	push	es			;2
	push	0x00		;3
	pop		es			;3
	lahf
	mov		es:[flags_debug],	ah
	pop		es			;2
	pop		ax			;1
	push	ax			;1
	call	print_char_newline_spi
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi
	pop		ax			;1
	popf				;0
	nop
	nop
	nop
	nop
	nop
	nop
	iret

print_cursor_pos:
	push	ax
	push	ds
	mov		ax,		0x0000
	mov		ds,		ax
	mov		al,		' '
	call	print_char_spi
	mov		ax,		cursor_pos_h		; print the address
	xchg	ah,		al
	call	print_char_hex_spi
	xchg	ah,		al
	call	print_char_hex_spi
	mov		al,		'='
	call	print_char_spi
	mov		ax,		[cursor_pos_h]
	xchg	al,		ah
	call	print_char_hex_spi
	xchg	al,		ah
	call	print_char_hex_spi
	mov		al,		','
	call	print_char_spi
	mov		ax,		[cursor_pos_v]
	xchg	al,		ah
	call	print_char_hex_spi
	xchg	al,		ah
	call	print_char_hex_spi
	mov		al,		'*'
	call	print_char_spi
	pop		ds
	pop		ax
	ret